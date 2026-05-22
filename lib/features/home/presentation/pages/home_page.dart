import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';
import 'package:kz_servicos_prestador/core/widgets/provider_bottom_nav.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/online_toggle.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/scheduled_trips_carousel.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/trip_request_card.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/driver_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/directions_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class HomePage extends StatefulWidget {
  final ValueChanged<int> onNavTap;

  const HomePage({super.key, required this.onNavTap});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  bool _isOnline = false;
  bool _showRequest = false;
  Timer? _requestTimer;
  final _tripService = TripService();
  final _driverService = DriverService();
  List<TripData> _requests = [];
  int _currentRequestIndex = 0;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  final DirectionsService _directionsService = DirectionsService();

  LatLng _currentLocation = const LatLng(-23.5505, -46.6333);
  bool _locationLoaded = false;

  // Pulse animation state
  AnimationController? _pulseController;
  List<LatLng> _routePoints = [];
  List<double> _routeDistances = [];
  double _routeTotalLength = 0;

  // Cached custom icons
  BitmapDescriptor? _yellowPinIcon;
  BitmapDescriptor? _yellowCircleIcon;
  BitmapDescriptor? _driverLocationIcon;

  // Floating messages icon drag state
  double? _msgIconLeft;
  double? _msgIconTop;

  RealtimeChannel? _invitationsChannel;

  TripData get _currentRequest => _requests[_currentRequestIndex];

  // Unread messages — driven by real chat later
  int get _totalUnreadMessages => 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initIcons();
    _load().then((_) => _subscribeToInvitations());
    AuthState.scheduledTrips?.addListener(_onScheduledTripsChanged);
  }

  Future<void> _load() async {
    final userId = AuthState.userId;
    final driverProfileId = AuthState.driverProfileId;
    debugPrint('[HomePage] _load — driverProfileId: $driverProfileId');
    if (driverProfileId == null) {
      debugPrint('[HomePage] driverProfileId é null — usuário não é motorista ou sessão não restaurou esse campo');
      return;
    }

    final profileFuture = _driverService.getDriverProfile(userId ?? '');
    final tripsFuture = _tripService.getDriverInvitations(driverProfileId);
    final profile = await profileFuture;
    final trips = await tripsFuture;

    if (!mounted) return;

    final isAvailable = profile?.isAvailable ?? false;
    setState(() => _isOnline = isAvailable);

    debugPrint('[HomePage] convites recebidos: ${trips.length}');
    if (trips.isNotEmpty) {
      setState(() {
        _requests = trips;
        _currentRequestIndex = 0;
        _showRequest = isAvailable;
      });
      if (isAvailable) _fetchRouteForCurrentRequest();
    }
  }

  void _onScheduledTripsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stopPulseAnimation();
    _requestTimer?.cancel();
    _invitationsChannel?.unsubscribe();
    AuthState.scheduledTrips?.removeListener(_onScheduledTripsChanged);
    super.dispose();
  }

  void _subscribeToInvitations() {
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null) return;
    _invitationsChannel = Supabase.instance.client
        .channel('driver-invitations-$driverProfileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trip_driver_candidates',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_profile_id',
            value: driverProfileId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  void _showNextRequest() {
    if (!mounted || !_isOnline || _requests.isEmpty) return;
    setState(() => _showRequest = true);
    _fetchRouteForCurrentRequest();
  }

  Future<void> _initIcons() async {
    _yellowPinIcon = await _createYellowPinIcon();
    _yellowCircleIcon = await _createYellowCircleIcon();
    _driverLocationIcon = await _createDriverLocationIcon();
    _updateDriverMarker();
  }

  Future<void> _initLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _locationLoaded = true;
      });
      _updateDriverMarker();
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation, 15),
      );
    } catch (_) {
      // Use default São Paulo position
    }
  }

  void _updateDriverMarker() {
    if (_driverLocationIcon == null) return;
    setState(() {
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'driver_location'),
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _currentLocation,
          icon: _driverLocationIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 10,
        ),
      };
    });
  }

  void _onToggleOnline(bool value) {
    setState(() {
      _isOnline = value;
      _currentRequestIndex = 0;
      _showRequest = false;
      _polylines = {};
      _markers = {};
    });
    _stopPulseAnimation();
    _requestTimer?.cancel();
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId != null) {
      _driverService.updateAvailability(driverProfileId, value);
    }
    if (value && _requests.isNotEmpty) {
      _showNextRequest();
    }
  }

  Future<void> _fetchRouteForCurrentRequest() async {
    final r = _currentRequest;
    final pickup = LatLng(r.originLat, r.originLng);
    final destination = LatLng(r.destinationLat, r.destinationLng);

    // Fetch both routes in parallel
    final results = await Future.wait([
      _directionsService.fetchRoute(origin: pickup, destination: destination),
      _directionsService.fetchRoute(
        origin: _currentLocation,
        destination: pickup,
      ),
    ]);

    final tripPoints = results[0].polyline;
    final driverToPickupPoints = results[1].polyline;

    if (!mounted) return;

    // Build markers
    final markers = <Marker>{};
    if (_driverLocationIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver_location'),
        position: _currentLocation,
        icon: _driverLocationIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 10,
      ));
    }
    if (_yellowPinIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        icon: _yellowPinIcon!,
      ));
    }
    if (_yellowCircleIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: _yellowCircleIcon!,
      ));
    }

    // Build polylines
    final polylines = <Polyline>{};

    // Driver → pickup route (subtle blue)
    if (driverToPickupPoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('driver_route'),
        points: driverToPickupPoints,
        color: AppColors.secondary.withValues(alpha: 0.4),
        width: 3,
      ));
    }

    // Trip route base (pickup → destination)
    if (tripPoints.isNotEmpty) {
      polylines.addAll({
        Polyline(
          polylineId: const PolylineId('route_glow'),
          points: tripPoints,
          color: AppColors.highlight.withValues(alpha: 0.18),
          width: 10,
        ),
        Polyline(
          polylineId: const PolylineId('route'),
          points: tripPoints,
          color: AppColors.highlight,
          width: 4,
        ),
      });
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    // Start pulse animation on trip route
    if (tripPoints.isNotEmpty) {
      _routePoints = tripPoints;
      _startPulseAnimation(tripPoints);
    }

    // Fit bounds to include all points
    _fitAllBounds(pickup, destination);
  }

  // ── Pulse animation (same as client app) ──

  void _startPulseAnimation(List<LatLng> points) {
    _stopPulseAnimation();
    if (points.length < 2) return;
    _routeDistances = _computeSegmentDistances(points);
    _routeTotalLength =
        _routeDistances.isEmpty ? 0 : _routeDistances.last;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _pulseController!.addListener(_updatePulsePolyline);
    _pulseController!.repeat();
  }

  void _stopPulseAnimation() {
    _pulseController?.removeListener(_updatePulsePolyline);
    _pulseController?.dispose();
    _pulseController = null;
  }

  List<double> _computeSegmentDistances(List<LatLng> pts) {
    final dists = <double>[0.0];
    for (int i = 1; i < pts.length; i++) {
      dists.add(dists.last + _haversine(pts[i - 1], pts[i]));
    }
    return dists;
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final hav = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  LatLng _interpolateAtDistance(double dist) {
    if (dist <= 0) return _routePoints.first;
    if (dist >= _routeTotalLength) return _routePoints.last;
    int lo = 0, hi = _routeDistances.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (_routeDistances[mid] <= dist) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final segStart = _routeDistances[lo];
    final segEnd = _routeDistances[hi];
    final t = (dist - segStart) / (segEnd - segStart);
    final a = _routePoints[lo];
    final b = _routePoints[hi];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  List<LatLng> _extractSubRoute(double from, double to) {
    final result = <LatLng>[];
    result.add(_interpolateAtDistance(from));
    for (int i = 0; i < _routeDistances.length; i++) {
      final d = _routeDistances[i];
      if (d > from && d < to) result.add(_routePoints[i]);
    }
    result.add(_interpolateAtDistance(to));
    return result;
  }

  void _updatePulsePolyline() {
    if (_routePoints.length < 2 || !mounted) return;
    final t = _pulseController!.value;
    const segmentRatio = 0.20;
    final headDist = t * (_routeTotalLength * (1 + segmentRatio));
    final tailDist = headDist - _routeTotalLength * segmentRatio;
    final clampedHead = headDist.clamp(0.0, _routeTotalLength);
    final clampedTail = tailDist.clamp(0.0, _routeTotalLength);

    if (clampedHead - clampedTail < 1) {
      setState(() {
        _polylines = {
          ..._polylines.where((p) =>
              p.polylineId.value != 'pulse_glow' &&
              p.polylineId.value != 'pulse_core'),
        };
      });
      return;
    }

    final glowPoints = _extractSubRoute(clampedTail, clampedHead);
    final fadeFactor = _computeFade(t);

    setState(() {
      _polylines = {
        ..._polylines.where((p) =>
            p.polylineId.value != 'pulse_glow' &&
            p.polylineId.value != 'pulse_core'),
        if (glowPoints.length >= 2)
          Polyline(
            polylineId: const PolylineId('pulse_glow'),
            points: glowPoints,
            color: Colors.white.withValues(alpha: 0.45 * fadeFactor),
            width: 12,
          ),
        if (glowPoints.length >= 2)
          Polyline(
            polylineId: const PolylineId('pulse_core'),
            points: glowPoints,
            color: Colors.white.withValues(alpha: 0.85 * fadeFactor),
            width: 5,
          ),
      };
    });
  }

  double _computeFade(double t) {
    const fadeZone = 0.08;
    if (t < fadeZone) return t / fadeZone;
    if (t > 1 - fadeZone) return (1 - t) / fadeZone;
    return 1.0;
  }

  // ── Custom marker icons (same as client app) ──

  Future<BitmapDescriptor> _createYellowPinIcon() async {
    const width = 32.0;
    const height = 44.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = AppColors.highlight;
    canvas.drawCircle(const Offset(width / 2, 14), 12, paint);
    final path = Path()
      ..moveTo(width / 2 - 8, 20)
      ..lineTo(width / 2, height - 2)
      ..lineTo(width / 2 + 8, 20)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      const Offset(width / 2, 14), 5, Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createYellowCircleIcon() async {
    const size = 28.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = AppColors.highlight.withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      9,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      7,
      Paint()..color = AppColors.highlight,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createDriverLocationIcon() async {
    const size = 32.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Outer glow
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = AppColors.highlight.withValues(alpha: 0.25),
    );
    // White border
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      10,
      Paint()..color = Colors.white,
    );
    // Yellow fill
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      8,
      Paint()..color = AppColors.highlight,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  // ── Map helpers ──

  void _fitAllBounds(LatLng pickup, LatLng destination) {
    if (_mapController == null) return;
    final allPoints = [_currentLocation, pickup, destination];
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;
    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  Future<void> _onAccept(double price) async {
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null) return;
    final request = _requests[_currentRequestIndex];
    final ok = await _tripService.acceptCandidate(
      request.tripId,
      driverProfileId,
      offeredPrice: price,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível aceitar a solicitação.')),
      );
      return;
    }
    _stopPulseAnimation();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitação aceita! Acompanhe em Agendamentos.'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
    _advanceToNextRequest();
  }

  Future<void> _onReject() async {
    final observation = await _showRejectDialog();
    if (observation == null) return; // cancelado
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null) return;
    final trip = _requests[_currentRequestIndex];
    final ok = await _tripService.rejectCandidate(
      trip.tripId,
      driverProfileId,
      observation: observation.isEmpty ? null : observation,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível recusar a solicitação.')),
      );
      return;
    }
    _stopPulseAnimation();
    _advanceToNextRequest();
  }

  void _advanceToNextRequest() {
    final remaining = List<TripData>.from(_requests)..removeAt(_currentRequestIndex);
    setState(() {
      _requests = remaining;
      _currentRequestIndex = 0;
      _showRequest = false;
      _polylines = {};
      _markers = {};
    });
    if (_requests.isNotEmpty) {
      _showNextRequest();
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Recusar solicitação',
          style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Você pode adicionar uma observação opcional explicando o motivo:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Observação (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(
              'Recusar',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 15,
            ),
            style: MapStyles.standard,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_locationLoaded) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLocation, 15),
                );
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Online/Offline toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: OnlineToggle(
                isOnline: _isOnline,
                onChanged: _onToggleOnline,
              ),
            ),
          ),

          // Status badge
          if (_isOnline && _showRequest)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Solicitação ${_currentRequestIndex + 1} de ${_requests.length}',
                    style: const TextStyle(
                      fontFamily: 'QuasimodoSemiBold',
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),

          // Trip request card
          if (_isOnline && _showRequest && _requests.isNotEmpty)
            Positioned(
              bottom: bottomPadding + 100,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => context.push(
                  '/schedule-detail?fromHome=true',
                  extra: _requests[_currentRequestIndex],
                ),
                child: TripRequestCard(
                  request: _requests[_currentRequestIndex],
                  onAccept: _onAccept,
                  onReject: _onReject,
                ),
              ),
            ),

          // Carousel de corridas agendadas (só quando não há convite ativo sendo exibido)
          if ((AuthState.scheduledTrips?.trips.isNotEmpty ?? false) &&
              !(_showRequest && _requests.isNotEmpty))
            Positioned(
              bottom: bottomPadding + 72,
              left: 0,
              right: 0,
              child: ScheduledTripsCarousel(
                trips: AuthState.scheduledTrips!.trips,
                onTap: (trip) => context.push('/schedule-detail', extra: trip),
              ),
            ),

          // My location button
          Positioned(
            right: 16,
            bottom: bottomPadding +
                ((_showRequest && _requests.isNotEmpty) ? 320 :
                 (AuthState.scheduledTrips?.trips.isNotEmpty ?? false) ? 260 : 100),
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLocation, 15),
                );
              },
              child: const Icon(Icons.my_location, color: AppColors.textPrimary),
            ),
          ),

          // Floating draggable messages icon
          if (_totalUnreadMessages > 0)
            Positioned(
              left: _msgIconLeft ?? MediaQuery.of(context).size.width - 52 - 24,
              top: _msgIconTop ??
                  MediaQuery.of(context).size.height -
                      bottomPadding -
                      12 -
                      72 -
                      52 -
                      16,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final screenSize = MediaQuery.of(context).size;
                    _msgIconLeft = ((_msgIconLeft ??
                                    screenSize.width - 52 - 24) +
                                details.delta.dx)
                            .clamp(0.0, screenSize.width - 52);
                    _msgIconTop = ((_msgIconTop ??
                                    screenSize.height -
                                        bottomPadding -
                                        12 -
                                        72 -
                                        52 -
                                        16) +
                                details.delta.dy)
                            .clamp(
                                MediaQuery.of(context).padding.top,
                                screenSize.height - 52 - bottomPadding);
                  });
                },
                onTap: () => context.push('/messages'),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.highlight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              '$_totalUnreadMessages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom nav
          Positioned(
            bottom: bottomPadding + 12,
            left: 24,
            right: 24,
            child: ProviderBottomNav(
              selectedIndex: 0,
              onItemSelected: widget.onNavTap,
            ),
          ),
        ],
      ),
    );
  }
}
