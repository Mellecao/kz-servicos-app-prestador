import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';
import 'package:kz_servicos_prestador/core/utils/custom_map_markers.dart';
import 'package:kz_servicos_prestador/core/utils/route_pulse_animator.dart';
import 'package:kz_servicos_prestador/core/widgets/circle_button.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/mock_trip_request.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/directions_service.dart';
import 'package:kz_servicos_prestador/features/trip/domain/trip_phase.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/helpers/external_nav_helper.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_panels.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/phase_badge.dart';

class ActiveTripPage extends StatefulWidget {
  final MockTripRequest request;
  const ActiveTripPage({super.key, required this.request});

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage>
    with TickerProviderStateMixin {
  TripPhase _phase = TripPhase.navigatingToClient;
  GoogleMapController? _mapController;
  int _clientRating = 0;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  final _directionsService = DirectionsService();
  LatLng _currentLocation = const LatLng(-23.5505, -46.6333);
  double _currentHeading = 0;
  StreamSubscription<Position>? _positionStream;
  RoutePulseAnimator? _pulseAnimator;
  BitmapDescriptor? _yellowPinIcon;
  BitmapDescriptor? _yellowCircleIcon;
  BitmapDescriptor? _driverIcon;

  LatLng get _pickup => LatLng(widget.request.originLat, widget.request.originLng);
  LatLng get _destination => LatLng(widget.request.destinationLat, widget.request.destinationLng);

  @override
  void initState() {
    super.initState();
    _pulseAnimator = RoutePulseAnimator(vsync: this, onTick: _onPulseTick);
    _initIcons();
    _initLocationTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pulseAnimator?.dispose();
    super.dispose();
  }

  Future<void> _initIcons() async {
    final results = await Future.wait([
      CustomMapMarkers.createYellowPinIcon(),
      CustomMapMarkers.createYellowCircleIcon(),
      CustomMapMarkers.createDriverLocationIcon(),
    ]);
    _yellowPinIcon = results[0];
    _yellowCircleIcon = results[1];
    _driverIcon = results[2];
    _rebuildMarkers();
    _fetchRouteForPhase();
  }

  Future<void> _initLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      _currentLocation = LatLng(pos.latitude, pos.longitude);
      _currentHeading = pos.heading;
      _rebuildMarkers();
      _updateCamera();
    } catch (_) {}
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _currentHeading = position.heading;
    });
    _rebuildMarkers();
    _updateCamera();
  }

  void _updateCamera() {
    if (_mapController == null || !_phase.isGpsMode) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: _currentLocation,
        zoom: 17,
        tilt: 60,
        bearing: _currentHeading,
      )),
    );
  }

  void _rebuildMarkers() {
    final markers = <Marker>{};
    if (_driverIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _currentLocation,
        icon: _driverIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 10,
      ));
    }
    if (_yellowPinIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup,
        icon: _yellowPinIcon!,
      ));
    }
    if (_yellowCircleIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        icon: _yellowCircleIcon!,
      ));
    }
    setState(() => _markers = markers);
  }

  Future<void> _fetchRouteForPhase() async {
    _pulseAnimator?.stop();
    LatLng target;
    Color routeColor;
    switch (_phase) {
      case TripPhase.navigatingToClient:
        target = _pickup;
        routeColor = AppColors.secondary;
      case TripPhase.tripInProgress:
        target = _destination;
        routeColor = AppColors.highlight;
      default:
        setState(() => _polylines = {});
        return;
    }
    final points = await _directionsService.fetchRoute(
      origin: _currentLocation,
      destination: target,
    );
    if (points.isEmpty || !mounted) return;
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route_glow'),
          points: points,
          color: routeColor.withValues(alpha: 0.18),
          width: 10,
        ),
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: routeColor,
          width: 5,
        ),
      };
    });
    _pulseAnimator?.start(points);
  }

  void _onPulseTick() {
    if (!mounted) return;
    final pulse = _pulseAnimator!.buildPulsePolylines();
    setState(() {
      _polylines = {
        ..._polylines.where((p) =>
            p.polylineId.value != 'pulse_glow' &&
            p.polylineId.value != 'pulse_core'),
        ...pulse,
      };
    });
  }

  void _advancePhase() {
    setState(() {
      _phase = switch (_phase) {
        TripPhase.navigatingToClient => TripPhase.arrivedAtClient,
        TripPhase.arrivedAtClient => TripPhase.tripInProgress,
        TripPhase.tripInProgress => TripPhase.tripCompleted,
        TripPhase.tripCompleted => TripPhase.tripCompleted,
      };
    });
    switch (_phase) {
      case TripPhase.arrivedAtClient:
        _pulseAnimator?.stop();
        setState(() => _polylines = {});
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _pickup, zoom: 15),
          ),
        );
      case TripPhase.tripInProgress: _fetchRouteForPhase();
      case TripPhase.tripCompleted:
        _pulseAnimator?.stop(); _positionStream?.cancel();
        setState(() => _polylines = {});
      default: break;
    }
  }

  LatLng get _navTarget =>
      (_phase == TripPhase.navigatingToClient || _phase == TripPhase.arrivedAtClient)
          ? _pickup : _destination;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickup,
              zoom: 17,
              tilt: 60,
            ),
            style: MapStyles.standard,
            onMapCreated: (c) {
              _mapController = c;
              _updateCamera();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: topPadding + 8,
            left: 16,
            child: CircleButton(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
            ),
          ),
          Positioned(
            top: topPadding + 8,
            left: 64,
            right: 64,
            child: PhaseBadge(phase: _phase),
          ),
          if (_phase.isActive)
            Positioned(
              right: 16,
              bottom: 220,
              child: CircleButton(
                icon: Icons.open_in_new_rounded,
                onTap: () => showExternalNavSheet(context, _navTarget),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _phase == TripPhase.tripCompleted
                ? TripCompletedPanel(
                    price: widget.request.estimatedPrice,
                    rating: _clientRating,
                    onRatingChanged: (r) =>
                        setState(() => _clientRating = r),
                    onFinish: () => context.go('/home'),
                  )
                : ActiveTripPanel(
                    clientName: widget.request.clientName,
                    // TODO Task 6: Pass ActiveTripData instead of widget.request
                    subtitle: _phase.subtitle(widget.request as dynamic),
                    phaseColor: _phase.color,
                    buttonLabel: _phase.buttonLabel,
                    onAdvance: _advancePhase,
                    onChat: () => context.push('/chat/0'),
                    onCall: () {},
                  ),
          ),
        ],
      ),
    );
  }
}