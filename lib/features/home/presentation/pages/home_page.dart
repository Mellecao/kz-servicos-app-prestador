import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/feature_flags.dart';
import 'package:kz_servicos_prestador/features/benefits/presentation/widgets/benefits_banner.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';
import 'package:kz_servicos_prestador/core/maps/kz_map.dart';
import 'package:kz_servicos_prestador/core/maps/route_polyline_builder.dart';
import 'package:kz_servicos_prestador/core/widgets/provider_bottom_nav.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/driver_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_chat_service.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/active_trip_return_button.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/pending_trip_requests_carousel.dart';
import 'package:kz_servicos_prestador/core/services/push_notification_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/features/home/domain/home_realtime_reload_policy.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/directions_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:kz_servicos_prestador/core/services/trip_audio_service.dart';
import 'package:kz_servicos_prestador/core/constants/app_geo.dart';

const double _driverDefaultZoom = 17.5;
const double _requestDriverRouteMaxDistanceMeters = 150000;
const Duration _requestRefreshFallbackInterval = Duration(seconds: 10);
const Duration _realtimeReloadDebounce = Duration(milliseconds: 350);

class _RoutePreview {
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  const _RoutePreview({required this.markers, required this.polylines});
}

class HomePage extends StatefulWidget {
  final ValueChanged<int> onNavTap;
  final String? tripRequestId;
  final String? activeTripId;

  const HomePage({
    super.key,
    required this.onNavTap,
    this.tripRequestId,
    this.activeTripId,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  KzMapController? _mapController;
  bool _isOnline = false;
  bool _showRequest = false;
  Timer? _requestTimer;
  final _tripService = TripService();
  final _driverService = DriverService();
  final _chatService = TripChatService();
  List<TripData> _requests = [];
  int _currentRequestIndex = 0;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  final DirectionsService _directionsService = DirectionsService();
  final TripAudioService _tripAudio = TripAudioService();
  int _routeRequestSerial = 0;
  bool _requestSurfaceOpen = false;
  String? _openedRequestTripId;

  LatLng _currentLocation = AppGeo.luanda;
  bool _locationLoaded = false;

  // Cached custom icons
  BitmapDescriptor? _brandPinIcon;
  BitmapDescriptor? _brandCircleIcon;
  BitmapDescriptor? _driverLocationIcon;

  // Floating messages icon drag state
  double? _msgIconLeft;
  double? _msgIconTop;

  RealtimeChannel? _invitationsChannel;
  RealtimeChannel? _driverTripsChannel;
  RealtimeChannel? _chatMessagesChannel;
  StreamSubscription<Map<String, dynamic>>? _pushEventsSubscription;
  int _totalUnreadMessages = 0;
  Timer? _reloadDebounceTimer;
  bool _loadInFlight = false;
  bool _reloadQueued = false;
  String? _routePreviewKey;
  final Map<String, _RoutePreview> _routePreviewCache = {};

  TripData get _currentRequest => _requests[_currentRequestIndex];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initIcons();
    _load().then((_) {
      _subscribeToInvitations();
      _startRequestRefreshWatchdog();
    });
    _loadUnreadMessages().then((_) => _subscribeToChatMessages());
    _subscribeToForegroundPushEvents();
  }

  Future<void> _load() async {
    if (_loadInFlight) {
      _reloadQueued = true;
      return;
    }

    _loadInFlight = true;
    final userId = AuthState.userId;
    final driverProfileId = AuthState.driverProfileId;
    debugPrint('[HomePage] _load — driverProfileId: $driverProfileId');
    if (driverProfileId == null) {
      debugPrint(
        '[HomePage] driverProfileId é null — utilizador não é motorista ou sessão não restaurou esse campo',
      );
      _loadInFlight = false;
      return;
    }

    try {
      final previousTripId = _requests.isNotEmpty
          ? _requests[_currentRequestIndex].tripId
          : null;
      final profileFuture = _driverService.getDriverProfile(userId ?? '');
      final tripsFuture = Future.wait([
        _tripService.getDriverRecheckRequests(driverProfileId),
        _tripService.getDriverInvitations(driverProfileId),
      ]);
      final profile = await profileFuture;
      final tripResults = await tripsFuture;
      final trips = [...tripResults[0], ...tripResults[1]];

      if (!mounted) return;

      final isAvailable = profile?.isAvailable ?? false;
      setState(() => _isOnline = isAvailable);

      if (_openedRequestTripId != null &&
          trips.every((trip) => trip.tripId != _openedRequestTripId)) {
        _openedRequestTripId = null;
      }

      debugPrint('[HomePage] convites recebidos: ${trips.length}');
      final nextIndex = _resolveRequestIndex(
        trips: trips,
        preferredTripId: previousTripId ?? widget.tripRequestId?.trim(),
      );
      setState(() {
        _requests = trips;
        _currentRequestIndex = nextIndex;
        _showRequest = trips.isNotEmpty && isAvailable;
        _requestSurfaceOpen = false;
        _routePreviewKey = null;
      });

      if (trips.isNotEmpty && isAvailable) {
        _showNextRequest();
      } else {
        _routePreviewKey = null;
        _tripAudio.stopNotification();
      }
    } finally {
      _loadInFlight = false;
      if (_reloadQueued && mounted) {
        _reloadQueued = false;
        unawaited(_load());
      }
    }
  }

  int _resolveRequestIndex({
    required List<TripData> trips,
    String? preferredTripId,
  }) {
    if (trips.isEmpty) return 0;
    final normalizedPreferred = preferredTripId?.trim();
    if (normalizedPreferred != null && normalizedPreferred.isNotEmpty) {
      final preferredIndex = trips.indexWhere(
        (request) => request.tripId == normalizedPreferred,
      );
      if (preferredIndex >= 0) return preferredIndex;
    }
    return 0;
  }

  @override
  void dispose() {
    _requestTimer?.cancel();
    _reloadDebounceTimer?.cancel();
    _invitationsChannel?.unsubscribe();
    _driverTripsChannel?.unsubscribe();
    _chatMessagesChannel?.unsubscribe();
    _pushEventsSubscription?.cancel();
    _tripAudio.stopNotification();
    unawaited(_tripAudio.dispose());
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
          callback: (payload) {
            if (HomeRealtimeReloadPolicy.candidateChangeTargetsDriver(
              driverProfileId: driverProfileId,
              newRecord: payload.newRecord,
              oldRecord: payload.oldRecord,
            )) {
              _handleCandidateRealtimeChange(payload);
            }
          },
        )
        .subscribe();

    _driverTripsChannel = Supabase.instance.client
        .channel('driver-trip-updates-$driverProfileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trips',
          callback: (payload) {
            if (HomeRealtimeReloadPolicy.tripChangeTargetsDriver(
              driverProfileId: driverProfileId,
              newRecord: payload.newRecord,
              oldRecord: payload.oldRecord,
            )) {
              _handleTripRealtimeChange(payload);
            }
          },
        )
        .subscribe();
  }

  void _handleCandidateRealtimeChange(PostgresChangePayload payload) {
    final record = payload.newRecord.isNotEmpty
        ? payload.newRecord
        : payload.oldRecord;
    final candidateId = '${record['id'] ?? ''}';
    final tripId = '${record['trip_id'] ?? ''}';
    final status = record['status'] as String?;
    if (candidateId.isEmpty && tripId.isEmpty) {
      _scheduleReload();
      return;
    }

    final index = _requests.indexWhere(
      (request) =>
          (candidateId.isNotEmpty && request.candidateId == candidateId) ||
          (tripId.isNotEmpty && request.tripId == tripId),
    );

    if (status != 'pending') {
      if (index >= 0) {
        _removeRequestAt(index);
      } else {
        _scheduleReload();
      }
      return;
    }

    if (index < 0) {
      _scheduleReload(delay: Duration.zero);
      return;
    }

    _updateRequestAt(
      index,
      _requests[index].copyWith(
        candidateStatus: status,
        offeredPrice: (record['offered_price'] as num?)?.toDouble(),
        priceRejectionReason: record['price_rejection_reason'] as String?,
        kzProposedPrice: (record['kz_proposed_price'] as num?)?.toDouble(),
        kzProposalLocked: record['kz_proposal_locked'] as bool?,
      ),
    );
  }

  void _handleTripRealtimeChange(PostgresChangePayload payload) {
    final record = payload.newRecord.isNotEmpty
        ? payload.newRecord
        : payload.oldRecord;
    final tripId = '${record['id'] ?? ''}';
    if (tripId.isEmpty) {
      _scheduleReload();
      return;
    }

    final index = _requests.indexWhere((request) => request.tripId == tripId);
    if (index < 0) {
      _scheduleReload(delay: Duration.zero);
      return;
    }

    final status = record['status'] as String?;
    if (status != 'searching_drivers' &&
        status != 'awaiting_driver_confirmation') {
      _removeRequestAt(index);
      return;
    }

    _updateRequestAt(index, _requests[index].copyWith(status: status));
  }

  void _startRequestRefreshWatchdog() {
    _requestTimer?.cancel();
    _requestTimer = Timer.periodic(_requestRefreshFallbackInterval, (_) {
      if (!_isOnline) return;
      _scheduleReload(delay: Duration.zero);
    });
  }

  void _scheduleReload({Duration delay = _realtimeReloadDebounce}) {
    _reloadDebounceTimer?.cancel();
    _reloadDebounceTimer = Timer(delay, () {
      if (mounted) unawaited(_load());
    });
  }

  void _subscribeToForegroundPushEvents() {
    _pushEventsSubscription = PushNotificationService.foregroundEvents.listen((
      data,
    ) {
      final type = '${data['type'] ?? data['event'] ?? ''}';
      if (PushNotificationService.isPersistentNotificationType(type)) {
        _scheduleReload(delay: Duration.zero);
      } else if (type == 'chat_message') {
        unawaited(_loadUnreadMessages(playSoundOnIncrease: true));
      }
    });
  }

  void _subscribeToChatMessages() {
    _chatMessagesChannel?.unsubscribe();
    final userId = AuthState.userId;
    if (userId == null) return;
    _chatMessagesChannel = Supabase.instance.client
        .channel('driver-chat-messages-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => _loadUnreadMessages(playSoundOnIncrease: true),
        )
        .subscribe();
  }

  Future<void> _loadUnreadMessages({bool playSoundOnIncrease = false}) async {
    final userId = AuthState.userId;
    if (userId == null) return;
    final count = await _chatService.countUnreadForProvider(userId);
    if (!mounted) return;
    if (playSoundOnIncrease && count > _totalUnreadMessages) {
      unawaited(_tripAudio.playAccept());
    }
    setState(() => _totalUnreadMessages = count);
  }

  void _showNextRequest() {
    if (!mounted || !_isOnline || _requests.isEmpty) return;
    if (_requestSurfaceOpen) return;
    setState(() => _showRequest = true);
    _fetchRouteForCurrentRequestIfNeeded();
    if (_requests.length == 1) {
      unawaited(_openRequestSurfaceIfNeeded());
      _tripAudio.stopNotification();
      return;
    }
    _tripAudio.playNotificationLoop();
  }

  void _updateRequestAt(int index, TripData updated) {
    if (!mounted || index < 0 || index >= _requests.length) return;
    setState(() {
      _requests = [
        for (var i = 0; i < _requests.length; i++)
          if (i == index) updated else _requests[i],
      ];
      if (_currentRequestIndex >= _requests.length) {
        _currentRequestIndex = 0;
      }
      _showRequest = _isOnline && _requests.isNotEmpty;
      _routePreviewKey = null;
    });
    if (_showRequest) {
      _fetchRouteForCurrentRequestIfNeeded();
    }
  }

  void _removeRequestAt(int index) {
    if (!mounted || index < 0 || index >= _requests.length) return;
    final remaining = List<TripData>.from(_requests)..removeAt(index);
    setState(() {
      _requests = remaining;
      if (remaining.isEmpty) {
        _currentRequestIndex = 0;
      } else if (_currentRequestIndex >= remaining.length) {
        _currentRequestIndex = remaining.length - 1;
      } else if (index < _currentRequestIndex) {
        _currentRequestIndex -= 1;
      }
      _showRequest = _isOnline && remaining.isNotEmpty;
      _routeRequestSerial++;
      _routePreviewKey = null;
      if (remaining.isEmpty) {
        _polylines = {};
        _markers = {};
      }
    });

    if (remaining.isNotEmpty) {
      _showNextRequest();
    } else {
      _tripAudio.stopNotification();
      _resetDriverMapView();
    }
  }

  Future<void> _initIcons() async {
    _brandPinIcon = await _createBrandPinIcon();
    _brandCircleIcon = await _createBrandCircleIcon();
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
      _resetDriverMapView();
    } catch (_) {
      // Mantém a posição padrão (Luanda)
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

  bool _isMobileLayout(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  double _defaultMsgIconLeft(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const iconSize = 52.0;
    if (_isMobileLayout(context)) {
      return (screenWidth - iconSize - 80).clamp(0.0, screenWidth - iconSize);
    }
    return 80;
  }

  double _defaultMsgIconTop(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return screenHeight - bottomPadding - 12 - 72 - 52 - 16;
  }

  void _fetchRouteForCurrentRequestIfNeeded() {
    if (_requests.isEmpty || _requestSurfaceOpen) {
      return;
    }
    final key = _requestRouteKey(_currentRequest);
    final cachedPreview = _routePreviewCache[key];
    if (cachedPreview != null) {
      setState(() {
        _markers = cachedPreview.markers;
        _polylines = cachedPreview.polylines;
        _routePreviewKey = key;
      });
      return;
    }
    if (_routePreviewKey == key) return;
    _routePreviewKey = key;
    unawaited(_fetchRouteForCurrentRequest());
  }

  String _requestRouteKey(TripData request) {
    return [
      request.tripId,
      request.originLat,
      request.originLng,
      request.destinationLat,
      request.destinationLng,
    ].join('|');
  }

  Future<void> _fetchRouteForCurrentRequest() async {
    if (_requestSurfaceOpen) return;
    final serial = ++_routeRequestSerial;
    final r = _currentRequest;
    final pickup = LatLng(r.originLat, r.originLng);
    final destination = LatLng(r.destinationLat, r.destinationLng);
    final includeDriverRoute = _isDriverNearPickup(pickup);

    _showRequestRoutePreview(
      pickup: pickup,
      destination: destination,
      tripPoints: const [],
      includeDriverLocation: includeDriverRoute,
    );

    final tripResult = await _directionsService.fetchRoute(
      origin: pickup,
      destination: destination,
    );
    final driverResult = includeDriverRoute
        ? await _directionsService.fetchRoute(
            origin: _currentLocation,
            destination: pickup,
          )
        : null;

    if (!mounted || _requests.isEmpty || serial != _routeRequestSerial) {
      return;
    }

    final tripPoints = tripResult.polyline;
    final driverToPickupPoints = driverResult?.polyline ?? const <LatLng>[];
    _showRequestRoutePreview(
      pickup: pickup,
      destination: destination,
      tripPoints: tripPoints,
      driverToPickupPoints: driverToPickupPoints,
      includeDriverLocation: includeDriverRoute,
    );
  }

  _RoutePreview _buildRequestRoutePreview({
    required LatLng pickup,
    required LatLng destination,
    required List<LatLng> tripPoints,
    List<LatLng> driverToPickupPoints = const [],
    bool includeDriverLocation = true,
  }) {
    final markers = <Marker>{};
    if (includeDriverLocation && _driverLocationIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _currentLocation,
          icon: _driverLocationIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 10,
        ),
      );
    }
    if (_brandPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: _brandPinIcon!,
        ),
      );
    }
    if (_brandCircleIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          icon: _brandCircleIcon!,
        ),
      );
    }

    final polylines = <Polyline>{};
    if (driverToPickupPoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_route'),
          points: driverToPickupPoints,
          color: AppColors.secondary.withValues(alpha: 0.4),
          width: 3,
        ),
      );
    }
    if (tripPoints.isNotEmpty) {
      polylines.addAll(RoutePolylineBuilder.brandRoute(tripPoints));
    }

    return _RoutePreview(markers: markers, polylines: polylines);
  }

  void _showRequestRoutePreview({
    required LatLng pickup,
    required LatLng destination,
    required List<LatLng> tripPoints,
    List<LatLng> driverToPickupPoints = const [],
    bool includeDriverLocation = true,
  }) {
    final preview = _buildRequestRoutePreview(
      pickup: pickup,
      destination: destination,
      tripPoints: tripPoints,
      driverToPickupPoints: driverToPickupPoints,
      includeDriverLocation: includeDriverLocation,
    );

    setState(() {
      _markers = preview.markers;
      _polylines = preview.polylines;
    });

    if (tripPoints.isNotEmpty && _routePreviewKey != null) {
      _routePreviewCache[_routePreviewKey!] = preview;
    }
  }

  bool _isDriverNearPickup(LatLng pickup) {
    final distanceMeters = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      pickup.latitude,
      pickup.longitude,
    );
    return distanceMeters <= _requestDriverRouteMaxDistanceMeters;
  }

  int _requestSurfaceIndex() {
    if (_requests.isEmpty) return -1;
    return _currentRequestIndex.clamp(0, _requests.length - 1);
  }

  Future<void> _openRequestSurfaceIfNeeded() async {
    if (!mounted || !_isOnline || _requests.isEmpty) return;
    if (_requests.length > 1) return;

    final index = _requestSurfaceIndex();
    if (index < 0 || index >= _requests.length) return;

    final request = _requests[index];
    if (_openedRequestTripId == request.tripId) return;

    setState(() {
      _requestSurfaceOpen = true;
      _openedRequestTripId = request.tripId;
      _routePreviewKey = null;
      _polylines = {};
      _markers = {};
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await context.push('/schedule-detail?fromHome=true', extra: request);
    if (!mounted) return;

    setState(() {
      _requestSurfaceOpen = false;
    });
    _scheduleReload(delay: Duration.zero);
  }

  Future<void> _openSelectedRequestDetails() async {
    if (!mounted || _requests.isEmpty || _requestSurfaceOpen) return;

    final index = _requestSurfaceIndex();
    if (index < 0 || index >= _requests.length) return;
    final request = _requests[index];

    setState(() {
      _requestSurfaceOpen = true;
      _openedRequestTripId = request.tripId;
    });

    await context.push('/schedule-detail?fromHome=true', extra: request);
    if (!mounted) return;

    setState(() {
      _requestSurfaceOpen = false;
    });
    _scheduleReload(delay: Duration.zero);
  }

  // ── Custom marker icons (same as client app) ──

  Future<BitmapDescriptor> _createBrandPinIcon() async {
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
      const Offset(width / 2, 14),
      5,
      Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createBrandCircleIcon() async {
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
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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
    // Brand fill
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      8,
      Paint()..color = AppColors.highlight,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  void _selectRequest(TripData request) {
    final index = _requests.indexWhere((trip) => trip.tripId == request.tripId);
    if (index < 0 || index == _currentRequestIndex) return;
    setState(() {
      _currentRequestIndex = index;
      _routePreviewKey = null;
    });
    _fetchRouteForCurrentRequestIfNeeded();
  }

  Future<void> _openSelectedRequestFromCard(TripData request) async {
    _selectRequest(request);
    _tripAudio.stopNotification();
    unawaited(_openSelectedRequestDetails());
  }

  void _resetDriverMapView() {
    _updateDriverMarker();
    _mapController?.animateTo(
      target: _currentLocation,
      zoom: _driverDefaultZoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final hasActiveTripShortcut =
        widget.activeTripId != null && widget.activeTripId!.isNotEmpty;
    final mapPadding = EdgeInsets.only(
      top:
          MediaQuery.of(context).padding.top +
          _homeBannerHeight(context) +
          (hasActiveTripShortcut ? 132 : 72),
      bottom:
          bottomPadding + ((_showRequest && _requests.isNotEmpty) ? 300 : 96),
      left: 16,
      right: 16,
    );

    return Scaffold(
      body: Stack(
        children: [
          KzMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: _driverDefaultZoom,
            ),
            style: MapStyles.standard,
            padding: mapPadding,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_locationLoaded) {
                controller.animateTo(
                  target: _currentLocation,
                  zoom: _driverDefaultZoom,
                );
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Clube de benefícios desativado (ver FeatureFlags).
          if (FeatureFlags.benefitsClubEnabled)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _buildHomeBanner(context),
            ),

          if (hasActiveTripShortcut)
            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                  (FeatureFlags.benefitsClubEnabled
                      ? _homeBannerHeight(context) + 18
                      : 8),
              left: 16,
              right: 16,
              child: ActiveTripReturnButton(
                onTap: () => context.go(
                  '/active-trip?tripId=${Uri.encodeComponent(widget.activeTripId!)}',
                ),
              ),
            ),

          // Status badge
          if (_isOnline && _showRequest && !_requestSurfaceOpen)
            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                  24 +
                  _homeBannerHeight(context) +
                  (hasActiveTripShortcut ? 64 : 0),
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                    _requests.length == 1
                        ? '1 solicitação pendente'
                        : 'Solicitação ${_currentRequestIndex + 1} de ${_requests.length}',
                    style: const TextStyle(
                      fontFamily: 'QuasimodoSemiBold',
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),

          // Pending request cards
          if (_isOnline &&
              _showRequest &&
              _requests.isNotEmpty &&
              !_requestSurfaceOpen)
            Positioned(
              bottom: bottomPadding + 100,
              left: 16,
              right: 16,
              child: PendingTripRequestsCarousel(
                trips: _requests,
                selectedTripId: _currentRequest.tripId,
                onTripChanged: _selectRequest,
                onTripTap: _openSelectedRequestFromCard,
              ),
            ),

          // My location button
          Positioned(
            right: 16,
            bottom:
                bottomPadding +
                ((_showRequest && _requests.isNotEmpty) ? 230 : 100),
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              onPressed: () {
                _resetDriverMapView();
              },
              child: const Icon(
                Icons.my_location,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Floating draggable messages icon
          if (_totalUnreadMessages > 0)
            Positioned(
              left: _msgIconLeft ?? _defaultMsgIconLeft(context),
              top: _msgIconTop ?? _defaultMsgIconTop(context),
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final screenSize = MediaQuery.of(context).size;
                    _msgIconLeft =
                        ((_msgIconLeft ?? _defaultMsgIconLeft(context)) +
                                details.delta.dx)
                            .clamp(0.0, screenSize.width - 52);
                    _msgIconTop =
                        ((_msgIconTop ?? _defaultMsgIconTop(context)) +
                                details.delta.dy)
                            .clamp(
                              MediaQuery.of(context).padding.top,
                              screenSize.height - 52 - bottomPadding,
                            );
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

  double _homeBannerHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 32;
    return (width / 3.19).clamp(88.0, 118.0);
  }

  Widget _buildHomeBanner(BuildContext context) {
    return BenefitsBanner(onTap: () => context.push('/benefits'));
  }
}
