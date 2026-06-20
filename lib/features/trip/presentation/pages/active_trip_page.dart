import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';
import 'package:kz_servicos_prestador/core/maps/kz_map.dart';
import 'package:kz_servicos_prestador/core/services/trip_chat_service.dart';
import 'package:kz_servicos_prestador/core/utils/custom_map_markers.dart';
import 'package:kz_servicos_prestador/core/utils/route_pulse_animator.dart';
import 'package:kz_servicos_prestador/core/widgets/circle_button.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/directions_service.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/driver_location_payload.dart';
import 'package:kz_servicos_prestador/features/trip/domain/trip_phase.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/helpers/external_nav_helper.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_panels.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_navigation_drawer.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/cancel_trip_sheet.dart';
import 'package:kz_servicos_prestador/core/services/navigation_audio_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_audio_service.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/navigation_instruction_banner.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/phase_badge.dart';

const double _navigationTiltZoom = 20;
const double _navigationNormalZoomThreshold = 18;
const double _navigationTilt = 75;

class ActiveTripPage extends StatefulWidget {
  final ActiveTripData trip;
  const ActiveTripPage({super.key, required this.trip});

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _supabase = Supabase.instance.client;

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

  BitmapDescriptor? _yellowPinIcon;
  BitmapDescriptor? _yellowCircleIcon;
  BitmapDescriptor? _navCarIcon;

  bool _showArrivedPopup = false;
  bool _isAdvancing = false;
  bool _paymentConfirmed = false;
  bool _isMarkingPaid = false;
  bool _isFinishing = false;
  bool _cameraFollowing = true;
  bool _isCameraAnimating = false;
  bool _navigationTiltEnabled = true;
  CameraPosition? _lastCameraPosition;
  final TripAudioService _tripAudio = TripAudioService();
  String _feedbackComment = '';

  // Rota GPS — pontos completos + progresso do motorista
  List<LatLng> _fullRoutePoints = [];
  int _routeProgressIndex = 0;
  LatLng? _lastRouteFetchLocation;

  LatLng get _pickup => LatLng(widget.trip.pickupLat, widget.trip.pickupLng);
  LatLng get _destination =>
      LatLng(widget.trip.destinationLat, widget.trip.destinationLng);

  @override
  void initState() {
    super.initState();
    _phase = _initialPhaseFor(widget.trip);
    _showArrivedPopup = _phase == TripPhase.arrivedAtClient;
    _paymentConfirmed = widget.trip.isDriverPaid;
    _pulseAnimator = RoutePulseAnimator(vsync: this, onTick: _onPulseTick);
    _initIcons();
    _initLocationTracking();
    _startGpsPublishing();
    _startCompass();
    _subscribeToTripCancellation();
  }

  TripPhase _initialPhaseFor(ActiveTripData trip) {
    if (trip.status == 'finished' || trip.finishedAt != null) {
      return TripPhase.tripCompleted;
    }
    if (trip.startedAt != null) return TripPhase.tripInProgress;
    if (trip.driverArrivedAt != null) return TripPhase.arrivedAtClient;
    return TripPhase.navigatingToClient;
  }

  @override
  void dispose() {
    _audioService.stop();
    _positionStream?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    _compassTimer?.cancel();
    _cameraAnimationReleaseTimer?.cancel();
    _gpsPublishTimer?.cancel();
    _tripCancellationChannel?.unsubscribe();
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
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      _currentLocation = LatLng(pos.latitude, pos.longitude);
      _currentHeading = pos.heading.isNaN ? 0.0 : pos.heading;
      _rebuildMarkers();
      _updateCamera();
      _fetchRouteForPhase();
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

  void _startCompass() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((e) => _accelValues = [e.x, e.y, e.z]);

    _magSub = magnetometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((e) => _magValues = [e.x, e.y, e.z]);

    // Atualiza câmera com heading da bússola a ~10 fps
    _compassTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_phase.isGpsMode || !_cameraFollowing) return;
      final heading = computeCompassHeading(_accelValues, _magValues);
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
        'speed': 0.0,
        'trip_id': widget.trip.id,
      }, onConflict: 'driver_profile_id');
    } catch (_) {}
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _currentHeading = position.heading.isNaN ? 0.0 : position.heading;
    });
    _rebuildMarkers();
    _updateCamera();
    _updateCurrentStep();
    if (_phase.isGpsMode) {
      _trimRouteToCurrentPosition();
      unawaited(_maybeRefetchRoute());
    }
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
    if (_mapController == null || !_phase.isGpsMode || !_cameraFollowing) {
      return;
    }
    _animateNavigationCamera();
  }

  void _animateNavigationCamera() {
    if (_mapController == null) return;
    _cameraAnimationReleaseTimer?.cancel();
    _isCameraAnimating = true;
    _mapController!.animateTo(
      target: _currentLocation,
      zoom: _navigationTiltEnabled ? _navigationTiltZoom : 17,
      tilt: _navigationTiltEnabled ? _navigationTilt : 0,
      bearing: _navigationTiltEnabled ? _currentHeading : 0,
    );
    _cameraAnimationReleaseTimer = Timer(const Duration(milliseconds: 900), () {
      _isCameraAnimating = false;
    });
  }

  void _recenterCamera() {
    setState(() {
      _cameraFollowing = true;
      _navigationTiltEnabled = true;
    });
    _updateCamera();
  }

  void _handleCameraMove(CameraPosition position) {
    _lastCameraPosition = position;
    if (!_phase.isGpsMode || _isCameraAnimating) return;
    if (position.zoom < _navigationNormalZoomThreshold &&
        _navigationTiltEnabled) {
      setState(() => _navigationTiltEnabled = false);
    }
  }

  void _handleCameraIdle() {
    final lastPosition = _lastCameraPosition;
    final shouldFlatten =
        _phase.isGpsMode &&
        !_cameraFollowing &&
        !_navigationTiltEnabled &&
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
        target = _destination;
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
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _fullRoutePoints,
          color: AppColors.highlight,
          width: 14,
        ),
      };
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
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: remaining,
          color: AppColors.highlight,
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
        });
        _pulseAnimator?.stop();
        setState(() => _polylines = {});
        _isCameraAnimating = true;
        _mapController?.animateTo(target: _pickup, zoom: 15);
      } else if (_phase == TripPhase.arrivedAtClient) {
        try {
          debugPrint('[KZ-P] Calling UPDATE started_at...');
          final res = await _supabase
              .from('trips')
              .update({'started_at': DateTime.now().toUtc().toIso8601String()})
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
          _cameraFollowing = true;
          _navigationTiltEnabled = true;
        });
        _updateCamera();
        _fetchRouteForPhase();
      } else if (_phase == TripPhase.tripInProgress) {
        try {
          debugPrint('[KZ-P] Calling UPDATE finished_at + status=finished...');
          final res = await _supabase
              .from('trips')
              .update({
                'status': 'finished',
                'finished_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', widget.trip.id)
              .select('id, finished_at, status');
          debugPrint('[KZ-P] UPDATE finished_at OK rows=$res');
        } catch (e, st) {
          debugPrint('[KZ-P] UPDATE finished_at FAILED: $e\n$st');
          rethrow;
        }
        setState(() => _phase = TripPhase.tripCompleted);
        _pulseAnimator?.stop();
        _positionStream?.cancel();
        _gpsPublishTimer?.cancel();
        setState(() => _polylines = {});
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

  void _openDrawerRoute(String route) {
    Navigator.of(context).pop();
    context.push(
      '$route?returnToActiveTripId=${Uri.encodeComponent(widget.trip.id)}',
    );
  }

  Future<void> _onCancelTrip(String reason) async {
    try {
      await _supabase
          .from('trips')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
            'cancellation_reason': reason,
          })
          .eq('id', widget.trip.id);
    } catch (e) {
      debugPrint('[KZ-P] cancel trip erro: $e');
    }
    _positionStream?.cancel();
    _gpsPublishTimer?.cancel();
    if (mounted) context.go('/home');
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
      : _destination;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
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
              zoom: _navigationTiltZoom,
              tilt: _navigationTilt,
              bearing: _currentHeading,
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
            buildingsEnabled: true,
            onCameraMoveStarted: () {
              if (!_isCameraAnimating && _phase.isGpsMode) {
                setState(() => _cameraFollowing = false);
              }
            },
            onCameraMove: _handleCameraMove,
            onCameraIdle: _handleCameraIdle,
          ),
          Positioned(
            top: topPadding + 8,
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
          if (_phase.isGpsMode &&
              _routeSteps.isNotEmpty &&
              _currentStepIndex < _routeSteps.length)
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
                    backgroundColor: _cameraFollowing
                        ? Colors.white
                        : AppColors.highlight,
                    iconColor: Colors.black87,
                    onTap: _recenterCamera,
                  ),
                ],
              ),
            ),
          if (_phase.isActive)
            Positioned(
              left: _phase.isGpsMode ? 48 : 16,
              right: _phase.isGpsMode ? 48 : 16,
              bottom: _phase.isGpsMode ? 252 : 220,
              child: _ExternalNavigationButton(
                onTap: () => showExternalNavSheet(context, _navTarget),
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
                onReportProblem: _showCancelSheet,
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
                      subtitle: _phase.subtitle(widget.trip),
                      phaseColor: _phase.color,
                      buttonLabel: _phase.buttonLabel,
                      onAdvance: _advancePhase,
                      onChat: _onChat,
                      onCall: _onCall,
                      onReportProblem: _showCancelSheet,
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

class _ExternalNavigationButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ExternalNavigationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.highlight,
      borderRadius: BorderRadius.circular(8),
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.navigation_rounded, color: Colors.black, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Abrir rota no Waze / Maps',
                    style: TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Nosso sistema de mapas e GPS está em fase de desenvolvimento e pode conter erros. Para uma melhor experiência, recomendamos o uso de aplicativos externos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
