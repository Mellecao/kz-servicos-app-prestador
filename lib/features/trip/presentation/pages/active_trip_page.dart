import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';
import 'package:kz_servicos_prestador/core/utils/custom_map_markers.dart';
import 'package:kz_servicos_prestador/core/utils/route_pulse_animator.dart';
import 'package:kz_servicos_prestador/core/widgets/circle_button.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/directions_service.dart';
import 'package:kz_servicos_prestador/features/trip/domain/trip_phase.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/helpers/external_nav_helper.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_panels.dart';
import 'package:kz_servicos_prestador/core/services/navigation_audio_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_audio_service.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/navigation_instruction_banner.dart';
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
  List<RouteStep> _routeSteps = [];
  int _currentStepIndex = 0;
  final _directionsService = DirectionsService();
  final _audioService = NavigationAudioService();

  LatLng _currentLocation = const LatLng(-23.5505, -46.6333);
  double _currentHeading = 0;
  StreamSubscription<Position>? _positionStream;
  Timer? _gpsPublishTimer;
  RoutePulseAnimator? _pulseAnimator;

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
  final TripAudioService _tripAudio = TripAudioService();
  String _feedbackComment = '';

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
    _audioService.stop();
    _positionStream?.cancel();
    _gpsPublishTimer?.cancel();
    _pulseAnimator?.dispose();
    unawaited(_tripAudio.dispose());
    super.dispose();
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
      _currentHeading = position.heading.isNaN ? 0.0 : position.heading;
    });
    _rebuildMarkers();
    _updateCamera();
    _updateCurrentStep();
  }

  void _updateCurrentStep() {
    if (!_phase.isGpsMode || _routeSteps.isEmpty) return;
    for (int i = _currentStepIndex; i < _routeSteps.length; i++) {
      final end = _routeSteps[i].endLocation;
      final dist = Geolocator.distanceBetween(
        _currentLocation.latitude, _currentLocation.longitude,
        end.latitude, end.longitude,
      );
      if (dist > 25) {
        if (_currentStepIndex != i) {
          setState(() => _currentStepIndex = i);
          _speakInstruction(_routeSteps[i].instruction);
        }
        return;
      }
    }
  }

  void _speakInstruction(String instruction) {
    _audioService.speak(instruction);
  }

  void _updateCamera() {
    if (_mapController == null || !_phase.isGpsMode || !_cameraFollowing) return;
    _isCameraAnimating = true;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: _currentLocation,
        zoom: 17.5,
        tilt: 45,
        bearing: _currentHeading,
      )),
    );
  }

  void _recenterCamera() {
    setState(() => _cameraFollowing = true);
    _updateCamera();
  }

  void _rebuildMarkers() {
    final markers = <Marker>{};
    if (_navCarIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _currentLocation,
        icon: _navCarIcon!,
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
        setState(() {
          _polylines = {};
          _routeSteps = [];
          _currentStepIndex = 0;
        });
        return;
    }
    final result = await _directionsService.fetchRoute(
      origin: _currentLocation,
      destination: target,
    );
    if (result.polyline.isEmpty || !mounted) return;
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route_glow'),
          points: result.polyline,
          color: AppColors.highlight.withValues(alpha: 0.18),
          width: 10,
        ),
        Polyline(
          polylineId: const PolylineId('route'),
          points: result.polyline,
          color: AppColors.highlight,
          width: 5,
        ),
      };
      _routeSteps = result.steps;
      _currentStepIndex = 0;
    });
    if (result.steps.isNotEmpty) {
      _speakInstruction(result.steps[0].instruction);
    }
    _pulseAnimator?.start(result.polyline);
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
    debugPrint('[KZ-P] _advancePhase START phase=$_phase isAdvancing=$_isAdvancing tripId=${widget.trip.id} uid=${_supabase.auth.currentUser?.id}');
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
              .update({'driver_arrived_at': DateTime.now().toUtc().toIso8601String()})
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
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _pickup, zoom: 15),
          ),
        );
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
        });
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
          const SnackBar(content: Text('Erro ao registrar pagamento. Tente novamente.')),
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
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickup,
              zoom: 17.5,
              tilt: 45,
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
            buildingsEnabled: false,
            onCameraMoveStarted: () {
              if (!_isCameraAnimating && _phase.isGpsMode) {
                setState(() => _cameraFollowing = false);
              }
            },
            onCameraIdle: () {
              _isCameraAnimating = false;
            },
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
          // Banner de instrução de navegação
          if (_phase.isGpsMode &&
              _routeSteps.isNotEmpty &&
              _currentStepIndex < _routeSteps.length)
            Positioned(
              top: topPadding + 58,
              left: 0,
              right: 0,
              child: NavigationInstructionBanner(
                step: _routeSteps[_currentStepIndex],
                phaseColor: _phase.color,
              ),
            ),
          if (_phase.isGpsMode)
            Positioned(
              right: 16,
              bottom: 332,
              child: CircleButton(
                icon: _audioService.isMuted
                    ? Icons.volume_off
                    : Icons.volume_up,
                onTap: () {
                  _audioService.toggleMute();
                  setState(() {});
                },
              ),
            ),
          if (_phase.isGpsMode && !_cameraFollowing)
            Positioned(
              right: 16,
              bottom: 276,
              child: CircleButton(
                icon: Icons.my_location,
                onTap: _recenterCamera,
              ),
            ),
          if (_phase.isActive)
            Positioned(
              right: 16,
              bottom: 220,
              child: CircleButton(
                icon: Icons.open_in_new_rounded,
                backgroundColor: AppColors.highlight,
                iconColor: Colors.black,
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
                          subtitle: _phase.subtitle(widget.trip),
                          phaseColor: _phase.color,
                          buttonLabel: _phase.buttonLabel,
                          onAdvance: _advancePhase,
                          onChat: () => context.push('/chat/0'),
                          onCall: _onCall,
                        )
                      : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
