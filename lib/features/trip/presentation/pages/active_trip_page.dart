import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:url_launcher/url_launcher.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';
import 'package:kz_servicos_prestador/core/maps/kz_map.dart';
import 'package:kz_servicos_prestador/core/services/trip_chat_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_cancellation_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/utils/custom_map_markers.dart';
import 'package:kz_servicos_prestador/core/utils/route_pulse_animator.dart';
import 'package:kz_servicos_prestador/core/widgets/circle_button.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/directions_service.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/driver_location_payload.dart';
import 'package:kz_servicos_prestador/features/trip/domain/navigation_camera_state.dart';
import 'package:kz_servicos_prestador/features/trip/domain/navigation_camera_preset.dart';
import 'package:kz_servicos_prestador/features/trip/domain/navigation_position_filter.dart';
import 'package:kz_servicos_prestador/features/trip/domain/active_trip_layout.dart';
import 'package:kz_servicos_prestador/features/trip/domain/trip_phase.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/helpers/external_nav_helper.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_panels.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_navigation_drawer.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/cancel_trip_sheet.dart';
import 'package:kz_servicos_prestador/core/services/navigation_audio_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_audio_service.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/navigation_instruction_banner.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/phase_badge.dart';

const Color _activeRouteBlue = Color(0xFF2261FE);
const LocationSettings _navigationLocationSettings = LocationSettings(
  accuracy: LocationAccuracy.bestForNavigation,
  distanceFilter: 1,
);

class ActiveTripPage extends StatefulWidget {
  final ActiveTripData trip;
  const ActiveTripPage({super.key, required this.trip});

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _supabase = Supabase.instance.client;
  final _tripCancellationService = TripCancellationService();
  final _tripService = TripService();

  TripPhase _phase = TripPhase.navigatingToClient;
  KzMapController? _mapController;
  int _clientRating = 0;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<RouteStep> _routeSteps = [];
  int _currentStepIndex = 0;
  String _routeDistanceText = '';
  String _routeDurationText = '';
  final _directionsService = DirectionsService();
  final _audioService = NavigationAudioService();

  LatLng _currentLocation = const LatLng(-23.5505, -46.6333);
  double _currentHeading = 0;
  double _currentSpeed = 0;
  Position? _lastAcceptedPosition;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  Timer? _compassTimer;
  Timer? _cameraAnimationReleaseTimer;
  List<double> _accelValues = [0, 0, 9.8];
  List<double> _magValues = [0, 0, 0];
  Timer? _gpsPublishTimer;
  RoutePulseAnimator? _pulseAnimator;
  RealtimeChannel? _tripCancellationChannel;
  RealtimeChannel? _cancellationRequestChannel;
  RealtimeChannel? _incomingRequestsChannel;

  BitmapDescriptor? _yellowPinIcon;
  BitmapDescriptor? _yellowCircleIcon;
  BitmapDescriptor? _navCarIcon;

  bool _showArrivedPopup = false;
  bool _isAdvancing = false;
  bool _paymentConfirmed = false;
  bool _isMarkingPaid = false;
  bool _isFinishing = false;
  bool _isCameraAnimating = false;
  bool _cancellationPending = false;
  bool _isRequestingCancellation = false;
  bool _openingIncomingRequest = false;
  DateTime? _lastCameraAnimationAt;
  final NavigationPositionFilter _positionFilter =
      const NavigationPositionFilter();
  NavigationCameraState _cameraState = const NavigationCameraState(
    following: true,
    tiltEnabled: true,
  );
  CameraPosition? _lastCameraPosition;
  final TripAudioService _tripAudio = TripAudioService();
  String _feedbackComment = '';
  String _executionStage = 'to_pickup';
  int? _currentStopOrder;

  // Rota GPS — pontos completos + progresso do motorista
  List<LatLng> _fullRoutePoints = [];
  int _routeProgressIndex = 0;
  LatLng? _lastRouteFetchLocation;

  LatLng get _pickup => LatLng(widget.trip.pickupLat, widget.trip.pickupLng);
  LatLng get _destination =>
      LatLng(widget.trip.destinationLat, widget.trip.destinationLng);
  ActiveTripStop? get _nextStop {
    for (final stop in widget.trip.stops) {
      if (stop.arrivedAt == null &&
          (_currentStopOrder == null || stop.order > _currentStopOrder!)) {
        return stop;
      }
    }
    return null;
  }

  bool get _isWaitingStage =>
      _executionStage == 'waiting_at_stop' ||
      _executionStage == 'waiting_for_return';
  LatLng get _routeTarget {
    if (_executionStage == 'to_stop') {
      final stop = _nextStop;
      if (stop != null) return LatLng(stop.latitude, stop.longitude);
    }
    if (_executionStage == 'returning') return _pickup;
    return _destination;
  }

  String get _executionButtonLabel => switch (_executionStage) {
    'to_stop' => 'Cheguei à parada',
    'waiting_at_stop' => 'Continuar viagem',
    'to_destination' =>
      widget.trip.isRoundTrip
          ? 'Cheguei ao destino de ida'
          : 'Finalizar viagem',
    'waiting_for_return' => 'Iniciar retorno',
    'returning' => 'Finalizar retorno',
    _ => _phase.buttonLabel,
  };
  String get _executionSubtitle => switch (_executionStage) {
    'to_stop' => _nextStop?.address ?? 'Próxima parada',
    'waiting_at_stop' => 'Aguardando retorno do passageiro',
    'waiting_for_return' => 'Aguardando retorno',
    'returning' => widget.trip.pickupAddress,
    _ => _phase.subtitle(widget.trip),
  };

  @override
  void initState() {
    super.initState();
    _executionStage =
        widget.trip.executionStage ??
        (widget.trip.startedAt != null ? 'to_destination' : 'to_pickup');
    _currentStopOrder = widget.trip.currentStopOrder;
    _phase = _initialPhaseFor(widget.trip);
    _showArrivedPopup = _phase == TripPhase.arrivedAtClient;
    _paymentConfirmed = widget.trip.isDriverPaid;
    _pulseAnimator = RoutePulseAnimator(vsync: this, onTick: _onPulseTick);
    _initIcons();
    _initLocationTracking();
    _startGpsPublishing();
    _startCompass();
    _subscribeToTripCancellation();
    _loadPendingCancellationRequest();
    _subscribeToCancellationRequests();
    _subscribeToIncomingRequests();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openIncomingRequest(showEmptyMessage: false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _openIncomingRequest(showEmptyMessage: false);
    }
  }

  TripPhase _initialPhaseFor(ActiveTripData trip) {
    if (trip.status == 'finished' || trip.finishedAt != null) {
      return TripPhase.tripCompleted;
    }
    if (trip.executionStage == 'to_pickup' ||
        (trip.executionStage == null && trip.startedAt == null)) {
      return TripPhase.navigatingToClient;
    }
    if (trip.startedAt != null || trip.executionStage != null) {
      return TripPhase.tripInProgress;
    }
    if (trip.driverArrivedAt != null) return TripPhase.arrivedAtClient;
    return TripPhase.navigatingToClient;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioService.stop();
    _positionStream?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    _compassTimer?.cancel();
    _cameraAnimationReleaseTimer?.cancel();
    _gpsPublishTimer?.cancel();
    _tripCancellationChannel?.unsubscribe();
    _cancellationRequestChannel?.unsubscribe();
    _incomingRequestsChannel?.unsubscribe();
    _pulseAnimator?.dispose();
    unawaited(_tripAudio.dispose());
    super.dispose();
  }

  void _subscribeToTripCancellation() {
    _tripCancellationChannel = _supabase
        .channel('active-trip-cancel-${widget.trip.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.trip.id,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete ||
                payload.newRecord['status'] == 'cancelled') {
              _handleRemoteCancellation();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadPendingCancellationRequest() async {
    try {
      final request = await _tripCancellationService.getPendingRequest(
        widget.trip.id,
      );
      if (!mounted) return;
      setState(() => _cancellationPending = request != null);
    } catch (e) {
      debugPrint('[KZ-P] load cancellation request erro: $e');
    }
  }

  void _subscribeToCancellationRequests() {
    _cancellationRequestChannel = _supabase
        .channel('active-trip-cancellation-request-${widget.trip.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trip_cancellation_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: widget.trip.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            if (payload.eventType == PostgresChangeEvent.delete) {
              setState(() => _cancellationPending = false);
              return;
            }

            final status = '${payload.newRecord['status'] ?? ''}';
            if (status == 'pending') {
              setState(() => _cancellationPending = true);
              return;
            }

            if (status == 'rejected') {
              final reason = '${payload.newRecord['review_reason'] ?? ''}'
                  .trim();
              setState(() => _cancellationPending = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    reason.isEmpty
                        ? 'A KZ recusou o cancelamento. A corrida continua ativa.'
                        : 'Cancelamento recusado: $reason',
                  ),
                ),
              );
              return;
            }

            if (status == 'approved') {
              setState(() => _cancellationPending = false);
            }
          },
        )
        .subscribe();
  }

  void _subscribeToIncomingRequests() {
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null || driverProfileId.isEmpty) return;
    _incomingRequestsChannel = _supabase
        .channel('active-trip-invitations-$driverProfileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_driver_candidates',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_profile_id',
            value: driverProfileId,
          ),
          callback: (_) {
            Future<void>.delayed(
              const Duration(milliseconds: 250),
              _openIncomingRequest,
            );
          },
        )
        .subscribe();
  }

  void _handleRemoteCancellation() {
    if (!mounted) return;
    _audioService.stop();
    _positionStream?.cancel();
    _gpsPublishTimer?.cancel();
    _pulseAnimator?.stop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Esta corrida foi cancelada pela KZ.')),
    );
    context.go('/home');
  }

  Future<void> _initIcons() async {
    final results = await Future.wait([
      CustomMapMarkers.createYellowPinIcon(),
      CustomMapMarkers.createYellowCircleIcon(),
      CustomMapMarkers.createNavCarIcon(),
    ]);
    _yellowPinIcon = results[0];
    _yellowCircleIcon = results[1];
    _navCarIcon = results[2];
    if (!mounted) return;
    _rebuildMarkers();
  }

  Future<void> _initLocationTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationSnack(
          'Ative a localização do aparelho para usar a navegação.',
        );
        await Geolocator.openLocationSettings();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationSnack(
          'Permita acesso preciso à localização para usar a navegação.',
        );
        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
        return;
      }
      await _requestTemporaryPreciseLocation();
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _navigationLocationSettings,
      );
      if (!mounted) return;
      _applyAcceptedPosition(pos);
      unawaited(_fetchRouteForPhase());
    } catch (e) {
      debugPrint('[KZ-P] init GPS erro: $e');
    }

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: _navigationLocationSettings,
        ).listen(
          _onPositionUpdate,
          onError: (e) {
            debugPrint('[KZ-P] GPS stream erro: $e');
          },
        );
  }

  Future<void> _requestTemporaryPreciseLocation() async {
    try {
      await Geolocator.requestTemporaryFullAccuracy(purposeKey: 'Navigation');
    } catch (_) {
      // Android e iOS sem localizacao aproximada podem ignorar essa chamada.
    }
  }

  void _showLocationSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startGpsPublishing() {
    _gpsPublishTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _publishLocation();
    });
  }

  void _startCompass() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((e) => _accelValues = [e.x, e.y, e.z]);

    _magSub = magnetometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((e) => _magValues = [e.x, e.y, e.z]);

    // Em movimento, o heading do GPS e mais estavel que a bussola.
    _compassTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!_phase.isGpsMode || !_cameraState.following) return;
      final heading = computeCompassHeading(_accelValues, _magValues);
      if (!heading.isFinite) return;
      final diff = (heading - _currentHeading + 360) % 360;
      if (diff < 2 || diff > 358) return; // Sem mudança significativa
      _currentHeading = heading;
      _animateNavigationCamera();
    });
  }

  Future<void> _publishLocation() async {
    if (!_phase.isPublishingGps) return;
    try {
      final userId = _supabase.auth.currentUser!.id;
      final driverProfile = await _supabase
          .from('driver_profiles')
          .select(DriverLocationPayload.driverProfileSelect)
          .eq('provider_profiles.user_id', userId)
          .single();
      await _supabase.from('driver_locations').upsert({
        'driver_profile_id': DriverLocationPayload.driverProfileIdFromRow(
          driverProfile,
        ),
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
        'heading': _currentHeading,
        'speed': _currentSpeed,
        'trip_id': widget.trip.id,
      }, onConflict: 'driver_profile_id');
    } catch (_) {}
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    if (!_positionFilter.shouldAccept(
      position,
      previous: _lastAcceptedPosition,
      now: DateTime.now().toUtc(),
    )) {
      debugPrint(
        '[KZ-P] GPS ignorado accuracy=${position.accuracy} '
        'speed=${position.speed} timestamp=${position.timestamp}',
      );
      return;
    }
    _applyAcceptedPosition(position);
    _updateCurrentStep();
    if (_phase.isGpsMode) {
      _trimRouteToCurrentPosition();
      unawaited(_maybeRefetchRoute());
    }
  }

  void _applyAcceptedPosition(Position position) {
    final compassHeading = computeCompassHeading(_accelValues, _magValues);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _currentSpeed = position.speed.isFinite ? position.speed : 0;
      _currentHeading = _positionFilter.resolveHeading(
        position: position,
        compassHeading: compassHeading,
        previousHeading: _currentHeading,
      );
      _lastAcceptedPosition = position;
    });
    _rebuildMarkers();
    _updateCamera();
  }

  void _updateCurrentStep() {
    if (!_phase.isGpsMode || _routeSteps.isEmpty) return;
    for (int i = _currentStepIndex; i < _routeSteps.length; i++) {
      final end = _routeSteps[i].endLocation;
      final dist = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        end.latitude,
        end.longitude,
      );
      if (dist > 25) {
        if (_currentStepIndex != i) {
          setState(() => _currentStepIndex = i);
          _speakStep(_routeSteps[i], dist);
        }
        return;
      }
    }
  }

  void _speakStep(RouteStep step, double remainingMeters) {
    unawaited(
      _audioService.speakManeuver(
        maneuver: step.maneuver,
        distanceMeters: remainingMeters,
      ),
    );
  }

  void _updateCamera() {
    if (_mapController == null ||
        !_phase.isGpsMode ||
        !_cameraState.following) {
      return;
    }
    _animateNavigationCamera();
  }

  void _animateNavigationCamera() {
    if (_mapController == null) return;
    final now = DateTime.now();
    final lastAnimation = _lastCameraAnimationAt;
    if (lastAnimation != null &&
        now.difference(lastAnimation) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastCameraAnimationAt = now;
    _cameraAnimationReleaseTimer?.cancel();
    _isCameraAnimating = true;
    _mapController!.animateTo(
      target: _currentLocation,
      zoom: _cameraState.tiltEnabled ? navigationTiltZoom : 17,
      tilt: _cameraState.tiltEnabled ? navigationTiltDegrees : 0,
      bearing: _cameraState.tiltEnabled ? _currentHeading : 0,
    );
    _cameraAnimationReleaseTimer = Timer(const Duration(milliseconds: 900), () {
      _isCameraAnimating = false;
    });
  }

  void _animateArrivedCamera() {
    if (_mapController == null) return;
    _cameraAnimationReleaseTimer?.cancel();
    _isCameraAnimating = true;
    _mapController!.animateTo(
      target: _pickup,
      zoom: navigationTiltZoom,
      tilt: navigationTiltDegrees,
      bearing: _currentHeading,
    );
    _cameraAnimationReleaseTimer = Timer(const Duration(milliseconds: 900), () {
      _isCameraAnimating = false;
    });
  }

  void _recenterCamera() {
    setState(() => _cameraState = _cameraState.withRecenter());
    _updateCamera();
  }

  void _handleCameraMove(CameraPosition position) {
    _lastCameraPosition = position;
    if (!_phase.isGpsMode || _isCameraAnimating) return;
    final next = _cameraState.withCameraMove(
      zoom: position.zoom,
      normalZoomThreshold: navigationNormalZoomThreshold,
    );
    if (next != _cameraState) {
      setState(() => _cameraState = next);
    }
  }

  void _handleCameraIdle() {
    final lastPosition = _lastCameraPosition;
    final shouldFlatten =
        _phase.isGpsMode &&
        !_cameraState.following &&
        !_cameraState.tiltEnabled &&
        lastPosition != null &&
        lastPosition.tilt > 0;
    _isCameraAnimating = false;
    _cameraAnimationReleaseTimer?.cancel();
    if (!shouldFlatten || _mapController == null) return;

    _isCameraAnimating = true;
    _mapController!.animateTo(
      target: lastPosition.target,
      zoom: lastPosition.zoom,
      tilt: 0,
      bearing: 0,
    );
  }

  void _rebuildMarkers() {
    final markers = <Marker>{};
    if (_navCarIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _currentLocation,
          icon: _navCarIcon!,
          rotation: _currentHeading,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 10,
        ),
      );
    }
    if (_yellowPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickup,
          icon: _yellowPinIcon!,
        ),
      );
    }
    if (_yellowCircleIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination,
          icon: _yellowCircleIcon!,
        ),
      );
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
        if (_isWaitingStage) {
          setState(() {
            _polylines = {};
            _routeSteps = [];
          });
          return;
        }
        target = _routeTarget;
      default:
        setState(() {
          _polylines = {};
          _routeSteps = [];
          _currentStepIndex = 0;
          _routeDistanceText = '';
          _routeDurationText = '';
        });
        return;
    }
    final result = await _directionsService.fetchRoute(
      origin: _currentLocation,
      destination: target,
    );
    if (!mounted) return;
    final routePoints = RouteRenderingPoints.fromResult(
      _currentLocation,
      target,
      resultPolyline: result.polyline,
    );
    _fullRoutePoints = routePoints;
    _routeProgressIndex = 0;
    _lastRouteFetchLocation = _currentLocation;
    final routePolyline = routePoints.length >= 2
        ? {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _fullRoutePoints,
              color: _activeRouteBlue,
              width: 14,
            ),
          }
        : <Polyline>{};
    setState(() {
      _polylines = routePolyline;
      _routeSteps = result.steps;
      _currentStepIndex = 0;
      _routeDistanceText = result.distanceText;
      _routeDurationText = result.durationText;
    });
    if (result.steps.isNotEmpty) {
      _speakStep(result.steps[0], result.steps[0].distanceMeters);
    }
    debugPrint(
      '[KZ-R] rota: ${routePoints.length} pontos (API=${result.polyline.isNotEmpty})',
    );
  }

  void _trimRouteToCurrentPosition() {
    if (_fullRoutePoints.isEmpty) return;
    final window = math.min(_routeProgressIndex + 50, _fullRoutePoints.length);
    double minDist = double.infinity;
    int closestIndex = _routeProgressIndex;
    for (int i = _routeProgressIndex; i < window; i++) {
      final d = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        _fullRoutePoints[i].latitude,
        _fullRoutePoints[i].longitude,
      );
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }
    if (closestIndex > _routeProgressIndex) {
      _routeProgressIndex = closestIndex;
    }
    final remaining = [
      _currentLocation,
      ..._fullRoutePoints.sublist(_routeProgressIndex),
    ];
    if (remaining.length < 2) return;
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: remaining,
          color: _activeRouteBlue,
          width: 14,
        ),
      };
    });
  }

  Future<void> _maybeRefetchRoute() async {
    final last = _lastRouteFetchLocation;
    if (last == null) return;
    final dist = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      last.latitude,
      last.longitude,
    );
    if (dist > 300) {
      await _fetchRouteForPhase();
    }
  }

  void _onPulseTick() {
    if (!mounted) return;
    final pulse = _pulseAnimator!.buildPulsePolylines();
    setState(() {
      _polylines = {
        ..._polylines.where(
          (p) =>
              p.polylineId.value != 'pulse_glow' &&
              p.polylineId.value != 'pulse_core',
        ),
        ...pulse,
      };
    });
  }

  Future<void> _advancePhase() async {
    debugPrint(
      '[KZ-P] _advancePhase START phase=$_phase isAdvancing=$_isAdvancing tripId=${widget.trip.id} uid=${_supabase.auth.currentUser?.id}',
    );
    if (_isAdvancing) {
      debugPrint('[KZ-P] _advancePhase BLOCKED (already advancing)');
      return;
    }
    _isAdvancing = true;
    try {
      if (_phase == TripPhase.navigatingToClient) {
        try {
          debugPrint('[KZ-P] Calling UPDATE driver_arrived_at...');
          final res = await _supabase
              .from('trips')
              .update({
                'driver_arrived_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', widget.trip.id)
              .select('id, driver_arrived_at, driver_profile_id, status');
          debugPrint('[KZ-P] UPDATE driver_arrived_at OK rows=$res');
        } catch (e, st) {
          debugPrint('[KZ-P] UPDATE driver_arrived_at FAILED: $e\n$st');
          rethrow;
        }
        setState(() {
          _phase = TripPhase.arrivedAtClient;
          _showArrivedPopup = true;
          _cameraState = _cameraState.withRecenter();
        });
        _pulseAnimator?.stop();
        setState(() => _polylines = {});
        _animateArrivedCamera();
      } else if (_phase == TripPhase.arrivedAtClient) {
        try {
          debugPrint('[KZ-P] Calling UPDATE started_at...');
          final res = await _supabase
              .from('trips')
              .update({
                'started_at': DateTime.now().toUtc().toIso8601String(),
                'execution_stage': widget.trip.stops.isEmpty
                    ? 'to_destination'
                    : 'to_stop',
              })
              .eq('id', widget.trip.id)
              .select('id, started_at, status');
          debugPrint('[KZ-P] UPDATE started_at OK rows=$res');
        } catch (e, st) {
          debugPrint('[KZ-P] UPDATE started_at FAILED: $e\n$st');
          rethrow;
        }
        setState(() {
          _phase = TripPhase.tripInProgress;
          _showArrivedPopup = false;
          _cameraState = _cameraState.withRecenter();
        });
        _updateCamera();
        await _fetchRouteForPhase();
      } else if (_phase == TripPhase.tripInProgress) {
        try {
          final stage = await _tripService.advanceTripExecution(widget.trip.id);
          if (stage == null) {
            throw StateError('Não foi possível avançar a corrida');
          }
          _executionStage = stage;
          if (stage == 'waiting_at_stop') {
            _currentStopOrder = _nextStop?.order ?? _currentStopOrder;
          }
          if (stage == 'finished') {
            setState(() => _phase = TripPhase.tripCompleted);
            _pulseAnimator?.stop();
            _positionStream?.cancel();
            _gpsPublishTimer?.cancel();
            setState(() => _polylines = {});
          } else {
            setState(() => _cameraState = _cameraState.withRecenter());
            await _fetchRouteForPhase();
          }
        } catch (e, st) {
          debugPrint('[KZ-P] advance trip execution FAILED: $e\n$st');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('[KZ-P] _advancePhase OUTER catch: $e');
    } finally {
      _isAdvancing = false;
      debugPrint('[KZ-P] _advancePhase END phase=$_phase');
    }
  }

  Future<void> _onPaymentConfirmed() async {
    if (_isMarkingPaid) return;
    _isMarkingPaid = true;
    try {
      await _supabase
          .from('trips')
          .update({'is_driver_paied': true})
          .eq('id', widget.trip.id);
      unawaited(_tripAudio.playPayment());
      if (mounted) setState(() => _paymentConfirmed = true);
    } catch (e) {
      debugPrint('[KZ-P] _onPaymentConfirmed erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao registrar pagamento. Tente novamente.'),
          ),
        );
      }
    } finally {
      _isMarkingPaid = false;
    }
  }

  Future<void> _onReportProblem() async {
    final trip = widget.trip;
    final scheduledAt = trip.scheduledAt;
    final dateStr = scheduledAt != null
        ? '${scheduledAt.day.toString().padLeft(2, '0')}/${scheduledAt.month.toString().padLeft(2, '0')}'
        : '';
    final timeStr = scheduledAt != null
        ? '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}'
        : '';
    final msg = Uri.encodeComponent(
      'Olá, tive um problema com o passageiro ${trip.clientName} na corrida de $dateStr às $timeStr, de ${trip.pickupAddress} para ${trip.destinationAddress}.',
    );
    final ok = await launchUrl(
      Uri.parse('https://wa.me/5511985889577?text=$msg'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  Future<void> _onCall() async {
    final phone = widget.trip.clientPhone;
    if (phone == null || phone.isEmpty) return;
    final ok = await launchUrl(
      Uri.parse('tel:$phone'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível iniciar a ligação.')),
      );
    }
  }

  Future<void> _onChat() async {
    final clientId = widget.trip.clientId;
    if (clientId == null) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final roomId = await TripChatService().getOrCreateChatRoom(
        tripId: widget.trip.id,
        clientId: clientId,
        providerId: userId,
      );
      if (roomId == null || !mounted) return;
      context.push(
        '/chat/$roomId',
        extra: ChatPageArgs(
          roomId: roomId,
          title: 'Corrida em andamento',
          subtitle:
              '${widget.trip.pickupAddress} → ${widget.trip.destinationAddress}',
          clientName: widget.trip.clientName,
          clientAvatarUrl: widget.trip.clientAvatarUrl,
          clientId: clientId,
          tripId: widget.trip.id,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o chat.')),
        );
      }
    }
  }

  void _showCancelSheet() {
    if (_cancellationPending || _isRequestingCancellation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O pedido de cancelamento ja esta em analise.'),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CancelTripSheet(onConfirm: _onCancelTrip),
    );
  }

  void _openTripMenu() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openSupportChat() {
    context.push('/support-chat');
  }

  Future<void> _openIncomingRequest({bool showEmptyMessage = true}) async {
    if (_openingIncomingRequest) return;
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null || driverProfileId.isEmpty) return;
    _openingIncomingRequest = true;
    try {
      final results = await Future.wait([
        _tripService.getDriverRecheckRequests(driverProfileId),
        _tripService.getDriverInvitations(driverProfileId),
      ]);
      if (!mounted) return;
      final requests = [...results[0], ...results[1]];
      if (requests.isEmpty) {
        if (showEmptyMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não há novas solicitações no momento.'),
            ),
          );
        }
        return;
      }
      await context.push(
        '/schedule-detail?fromHome=true',
        extra: requests.first,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar solicitações.'),
          ),
        );
      }
    } finally {
      _openingIncomingRequest = false;
    }
  }

  void _openDrawerRoute(String route) {
    Navigator.of(context).pop();
    if (route == '/home') {
      context.push('/home?activeTripId=${Uri.encodeComponent(widget.trip.id)}');
      return;
    }
    context.push(
      '$route?returnToActiveTripId=${Uri.encodeComponent(widget.trip.id)}',
    );
  }

  Future<void> _onCancelTrip(String reason) async {
    if (_cancellationPending || _isRequestingCancellation) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entre novamente para enviar o pedido.'),
          ),
        );
      }
      return;
    }

    setState(() => _isRequestingCancellation = true);
    try {
      await _tripCancellationService.requestCancellation(
        tripId: widget.trip.id,
        requestedBy: userId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _cancellationPending = true);
      final draft = Uri.encodeComponent(
        'Olá, preciso cancelar a corrida de ${widget.trip.pickupAddress} para ${widget.trip.destinationAddress}. Motivo informado: $reason',
      );
      if (mounted) context.push('/support-chat?draft=$draft');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pedido enviado. A corrida continua ativa durante a analise.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[KZ-P] request cancellation erro: $e');
      try {
        final pending = await _tripCancellationService.getPendingRequest(
          widget.trip.id,
        );
        if (!mounted) return;
        if (pending != null) {
          setState(() => _cancellationPending = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('O pedido ja esta em analise.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nao foi possivel enviar o pedido. Tente novamente.',
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nao foi possivel enviar o pedido. Tente novamente.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isRequestingCancellation = false);
    }
  }

  Future<void> _onFinish() async {
    if (_isFinishing) return;
    _isFinishing = true;
    if (_clientRating > 0 && widget.trip.clientId != null) {
      try {
        await _supabase.from('ratings').insert({
          'trip_id': widget.trip.id,
          'rater_id': _supabase.auth.currentUser!.id,
          'rated_id': widget.trip.clientId,
          'rating': _clientRating.toDouble(),
          if (_feedbackComment.isNotEmpty) 'comment': _feedbackComment,
        });
      } catch (e) {
        debugPrint('[KZ-P] rating insert erro: $e');
      }
    }
    if (mounted) context.go('/home');
  }

  LatLng get _navTarget =>
      (_phase == TripPhase.navigatingToClient ||
          _phase == TripPhase.arrivedAtClient)
      ? _pickup
      : _routeTarget;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final showNavigationBanner =
        _phase.isGpsMode &&
        _routeSteps.isNotEmpty &&
        _currentStepIndex < _routeSteps.length;
    final mapPadding = EdgeInsets.only(
      top: topPadding + 96,
      bottom: bottomPadding + (_cancellationPending ? 375 : 315),
      left: 8,
      right: 8,
    );
    return Scaffold(
      key: _scaffoldKey,
      drawer: ActiveTripNavigationDrawer(
        clientName: widget.trip.clientName,
        destinationAddress: widget.trip.destinationAddress,
        onSelectRoute: _openDrawerRoute,
      ),
      body: Stack(
        children: [
          KzMap(
            initialCameraPosition: CameraPosition(
              target: _pickup,
              zoom: navigationTiltZoom,
              tilt: navigationTiltDegrees,
              bearing: _currentHeading,
            ),
            style: MapStyles.standard,
            padding: mapPadding,
            onMapCreated: (c) {
              _mapController = c;
              _updateCamera();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            buildingsEnabled: false,
            scrollGesturesEnabled: !_phase.isGpsMode,
            rotateGesturesEnabled: !_phase.isGpsMode,
            tiltGesturesEnabled: !_phase.isGpsMode,
            onCameraMoveStarted: () {
              if (!_phase.isGpsMode || _isCameraAnimating) return;
              setState(() => _cameraState = _cameraState.withManualGesture());
            },
            onCameraMove: _handleCameraMove,
            onCameraIdle: _handleCameraIdle,
          ),
          Positioned(
            top:
                topPadding +
                activeTripMenuTopOffset(
                  showNavigationBanner: showNavigationBanner,
                ),
            left: 16,
            child: _LargeMenuButton(onTap: _openTripMenu),
          ),
          if (_phase != TripPhase.navigatingToClient &&
              _phase != TripPhase.arrivedAtClient &&
              context.canPop())
            Positioned(
              top: topPadding + 8,
              right: 16,
              child: CircleButton(
                icon: Icons.arrow_back,
                onTap: () => context.pop(),
              ),
            ),
          if (!_phase.isGpsMode)
            Positioned(
              top: topPadding + 8,
              left: 64,
              right: 64,
              child: PhaseBadge(phase: _phase),
            ),
          // Banner de instrução de navegação
          if (showNavigationBanner)
            Positioned(
              top: topPadding + 12,
              left: 0,
              right: 0,
              child: NavigationInstructionBanner(
                step: _routeSteps[_currentStepIndex],
                phaseColor: _phase.color,
                routeDistanceText: _routeDistanceText,
                routeDurationText: _routeDurationText,
              ),
            ),
          if (_phase.isGpsMode)
            Positioned(
              right: 16,
              top: topPadding + 148,
              child: _CompassButton(heading: _currentHeading),
            ),
          if (_phase.isGpsMode)
            Positioned(
              right: 16,
              top: topPadding + 204,
              child: Column(
                children: [
                  CircleButton(
                    icon: _audioService.isMuted
                        ? Icons.volume_off
                        : Icons.volume_up,
                    onTap: () {
                      _audioService.toggleMute();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  CircleButton(
                    icon: Icons.my_location,
                    backgroundColor: _cameraState.following
                        ? Colors.white
                        : AppColors.highlight,
                    iconColor: Colors.black87,
                    onTap: _recenterCamera,
                  ),
                ],
              ),
            ),
          Positioned(
            top: topPadding + 8,
            right: context.canPop() ? 72 : 16,
            child: CircleButton(
              icon: Icons.notifications_active_outlined,
              onTap: _openIncomingRequest,
            ),
          ),
          if (_showArrivedPopup)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ArrivedAtClientPanel(
                trip: widget.trip,
                onStart: _advancePhase,
                onCall: _onCall,
                onChat: _onChat,
                onSupportChat: _openSupportChat,
                onReportProblem: _showCancelSheet,
                cancellationPending: _cancellationPending,
                cancellationRequesting: _isRequestingCancellation,
              ),
            )
          else
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _phase == TripPhase.tripCompleted
                  ? !_paymentConfirmed
                        ? PaymentCollectionPanel(
                            price: widget.trip.offeredPrice,
                            clientName: widget.trip.clientName,
                            paymentMethodLabel: widget.trip.paymentMethodLabel,
                            onConfirm: _onPaymentConfirmed,
                          )
                        : TripCompletedPanel(
                            price: widget.trip.offeredPrice,
                            rating: _clientRating,
                            onRatingChanged: (r) =>
                                setState(() => _clientRating = r),
                            onCommentChanged: (c) => _feedbackComment = c,
                            onReportProblem: _onReportProblem,
                            onFinish: _onFinish,
                          )
                  : _phase != TripPhase.arrivedAtClient
                  ? ActiveTripPanel(
                      clientName: widget.trip.clientName,
                      clientAvatarUrl: widget.trip.clientAvatarUrl,
                      subtitle: _executionSubtitle,
                      phaseColor: _phase.color,
                      buttonLabel: _executionButtonLabel,
                      onAdvance: _advancePhase,
                      onChat: _onChat,
                      onSupportChat: _openSupportChat,
                      onCall: _onCall,
                      onOpenExternalNavigation: () =>
                          showExternalNavSheet(context, _navTarget),
                      showExternalNavigation:
                          _phase == TripPhase.navigatingToClient ||
                          _phase == TripPhase.tripInProgress &&
                              !_isWaitingStage,
                      onReportProblem: _showCancelSheet,
                      cancellationPending: _cancellationPending,
                      cancellationRequesting: _isRequestingCancellation,
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _CompassButton extends StatelessWidget {
  final double heading;

  const _CompassButton({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Transform.rotate(
        angle: -heading * math.pi / 180,
        child: const Icon(
          Icons.explore_rounded,
          color: AppColors.secondary,
          size: 26,
        ),
      ),
    );
  }
}

class _LargeMenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LargeMenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 54,
          height: 54,
          child: Icon(
            Icons.menu_rounded,
            color: AppColors.textPrimary,
            size: 30,
          ),
        ),
      ),
    );
  }
}
