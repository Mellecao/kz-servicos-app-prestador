import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';
import 'package:kz_servicos_prestador/core/utils/custom_map_markers.dart';
import 'package:kz_servicos_prestador/core/utils/route_pulse_animator.dart';
import 'package:kz_servicos_prestador/core/widgets/circle_button.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/directions_service.dart';
import 'package:kz_servicos_prestador/features/trip/domain/trip_phase.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/helpers/external_nav_helper.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_panels.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/phase_badge.dart';

class ActiveTripPage extends StatefulWidget {
  final ActiveTripData trip;
  const ActiveTripPage({super.key, required this.trip});

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  TripPhase _phase = TripPhase.navigatingToClient;
  GoogleMapController? _mapController;
  int _clientRating = 0;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  final _directionsService = DirectionsService();

  LatLng _currentLocation = const LatLng(-23.5505, -46.6333);
  double _currentHeading = 0;
  StreamSubscription<Position>? _positionStream;
  Timer? _gpsPublishTimer;
  RoutePulseAnimator? _pulseAnimator;

  BitmapDescriptor? _yellowPinIcon;
  BitmapDescriptor? _yellowCircleIcon;
  BitmapDescriptor? _blueTriangleIcon;

  bool _showArrivedPopup = false;

  LatLng get _pickup =>
      LatLng(widget.trip.pickupLat, widget.trip.pickupLng);
  LatLng get _destination =>
      LatLng(widget.trip.destinationLat, widget.trip.destinationLng);

  @override
  void initState() {
    super.initState();
    _pulseAnimator = RoutePulseAnimator(vsync: this, onTick: _onPulseTick);
    _initIcons();
    _initLocationTracking();
    _startGpsPublishing();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _gpsPublishTimer?.cancel();
    _pulseAnimator?.dispose();
    super.dispose();
  }

  Future<void> _initIcons() async {
    final results = await Future.wait([
      CustomMapMarkers.createYellowPinIcon(),
      CustomMapMarkers.createYellowCircleIcon(),
      CustomMapMarkers.createBlueTriangleIcon(),
    ]);
    _yellowPinIcon = results[0];
    _yellowCircleIcon = results[1];
    _blueTriangleIcon = results[2];
    _rebuildMarkers();
    _fetchRouteForPhase();
  }

  Future<void> _initLocationTracking() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
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

  void _startGpsPublishing() {
    _gpsPublishTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _publishLocation();
    });
  }

  Future<void> _publishLocation() async {
    if (!_phase.isGpsMode) return;
    try {
      final userId = _supabase.auth.currentUser!.id;
      final driverProfile = await _supabase
          .from('driver_profiles')
          .select('id')
          .eq('provider_profile_id', userId)
          .single();
      await _supabase.from('driver_locations').upsert({
        'driver_profile_id': driverProfile['id'] as String,
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
        'heading': _currentHeading,
        'speed': 0.0,
        'trip_id': widget.trip.id,
      }, onConflict: 'driver_profile_id');
    } catch (_) {}
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
    if (_blueTriangleIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _currentLocation,
        icon: _blueTriangleIcon!,
        rotation: _currentHeading,
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
    switch (_phase) {
      case TripPhase.navigatingToClient:
        target = _pickup;
      case TripPhase.tripInProgress:
        target = _destination;
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
          color: AppColors.highlight.withValues(alpha: 0.18),
          width: 10,
        ),
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: AppColors.highlight,
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

  Future<void> _advancePhase() async {
    if (_phase == TripPhase.navigatingToClient) {
      await _supabase
          .from('trips')
          .update({'driver_arrived_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', widget.trip.id);
      setState(() {
        _phase = TripPhase.arrivedAtClient;
        _showArrivedPopup = true;
      });
      _pulseAnimator?.stop();
      setState(() => _polylines = {});
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _pickup, zoom: 15),
        ),
      );
    } else if (_phase == TripPhase.arrivedAtClient) {
      await _supabase
          .from('trips')
          .update({'started_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', widget.trip.id);
      setState(() {
        _phase = TripPhase.tripInProgress;
        _showArrivedPopup = false;
      });
      _fetchRouteForPhase();
    } else if (_phase == TripPhase.tripInProgress) {
      setState(() => _phase = TripPhase.tripCompleted);
      _pulseAnimator?.stop();
      _positionStream?.cancel();
      _gpsPublishTimer?.cancel();
      setState(() => _polylines = {});
    }
  }

  LatLng get _navTarget =>
      (_phase == TripPhase.navigatingToClient ||
              _phase == TripPhase.arrivedAtClient)
          ? _pickup
          : _destination;

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
          if (_showArrivedPopup)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              // TODO Task 7: Replace with ArrivedAtClientPanel(trip: widget.trip, onStart: _advancePhase)
              child: ActiveTripPanel(
                clientName: widget.trip.clientName,
                subtitle: _phase.subtitle(widget.trip),
                phaseColor: _phase.color,
                buttonLabel: _phase.buttonLabel,
                onAdvance: _advancePhase,
                onChat: () => context.push('/chat/0'),
                onCall: () {},
              ),
            )
          else
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _phase == TripPhase.tripCompleted
                  ? TripCompletedPanel(
                      price: widget.trip.offeredPrice,
                      rating: _clientRating,
                      onRatingChanged: (r) =>
                          setState(() => _clientRating = r),
                      onFinish: () => context.go('/home'),
                    )
                  : _phase != TripPhase.arrivedAtClient
                      ? ActiveTripPanel(
                          clientName: widget.trip.clientName,
                          subtitle: _phase.subtitle(widget.trip),
                          phaseColor: _phase.color,
                          buttonLabel: _phase.buttonLabel,
                          onAdvance: _advancePhase,
                          onChat: () => context.push('/chat/0'),
                          onCall: () {},
                        )
                      : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
