import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';
import 'package:kz_servicos_prestador/core/maps/kz_map.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/trip_chat_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_cancellation_service.dart';
import 'package:kz_servicos_prestador/features/schedules/domain/schedule_detail_mode.dart';
import 'package:kz_servicos_prestador/features/schedules/data/repositories/scheduled_direct_repository.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/directions_service.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/cancel_trip_sheet.dart';

class ScheduleDetailPage extends StatefulWidget {
  final TripData trip;

  /// true quando vem da home (corrida disponível), false quando vem de agendamentos.
  final bool fromHome;

  const ScheduleDetailPage({
    super.key,
    required this.trip,
    this.fromHome = false,
  });

  @override
  State<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends State<ScheduleDetailPage>
    with SingleTickerProviderStateMixin {
  final _observationController = TextEditingController();
  final _priceController = TextEditingController();
  final _directionsService = DirectionsService();
  bool _observationError = false;
  bool _priceError = false;
  bool _isLoading = false;
  bool _routeLoaded = false;
  final _tripService = TripService();
  final _scheduledDirectRepository = ScheduledDirectRepository();
  final _tripCancellationService = TripCancellationService();
  RealtimeChannel? _tripChannel;
  KzMapController? _mapController;
  Set<Marker> _requestMarkers = {};
  Set<Polyline> _requestPolylines = {};
  late TripData _currentTrip;
  late final AnimationController _viewportPulseController;
  late final Animation<double> _viewportPulse;

  TripData get _trip => _currentTrip;

  // Na home: motorista pode responder a qualquer convite pendente.
  // Em agendamentos: só confirma se foi diretamente atribuído e aguarda confirmação.
  bool get _canRespond => widget.fromHome
      ? _trip.canDriverRespond
      : _trip.status == 'awaiting_driver_confirmation';

  bool get _isDriverRecheck => _trip.isDriverRecheck;

  bool get _isScheduledDirectRequest => _trip.isScheduledDirectRequest;

  String get _pageTitle =>
      widget.fromHome ? 'Solicitação de corrida' : 'Detalhes do agendamento';

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _syncKzPrice();
    _viewportPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _viewportPulse = CurvedAnimation(
      parent: _viewportPulseController,
      curve: Curves.easeInOut,
    );
    _subscribeToTripCancellation();
    if (widget.fromHome) {
      unawaited(_loadRequestRoute());
    }
  }

  @override
  void dispose() {
    _tripChannel?.unsubscribe();
    _observationController.dispose();
    _priceController.dispose();
    _viewportPulseController.dispose();
    super.dispose();
  }

  void _syncKzPrice() {
    final kzPrice = _trip.kzProposedPrice;
    if (_trip.kzProposalLocked && kzPrice != null) {
      _priceController.text = kzPrice.toStringAsFixed(2).replaceAll('.', ',');
    } else if (_isDriverRecheck) {
      final value = _trip.price > 0 ? _trip.price : (_trip.offeredPrice ?? 0);
      if (value > 0) {
        _priceController.text = value.toStringAsFixed(2).replaceAll('.', ',');
      }
    }
  }

  void _subscribeToTripCancellation() {
    _tripChannel = Supabase.instance.client
        .channel('schedule-detail-${_trip.tripId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _trip.tripId,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Esta corrida foi cancelada pela KZ.')),
    );
    context.go('/home');
  }

  Future<void> _loadRequestRoute() async {
    final origin = LatLng(_trip.originLat, _trip.originLng);
    final dest = LatLng(_trip.destinationLat, _trip.destinationLng);
    setState(() {
      _requestMarkers = _buildRequestMarkers(origin, dest);
    });

    try {
      final result = await _directionsService.fetchRoute(
        origin: origin,
        destination: dest,
      );
      if (!mounted) return;
      final points = result.polyline.isNotEmpty
          ? result.polyline
          : <LatLng>[origin, dest];
      setState(() {
        _requestPolylines = {
          Polyline(
            polylineId: const PolylineId('request_route'),
            points: points,
            color: AppColors.highlight,
            width: 6,
          ),
        };
        _routeLoaded = true;
      });
      await _fitRequestRoute(points);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requestPolylines = {
          Polyline(
            polylineId: const PolylineId('request_route_fallback'),
            points: [origin, dest],
            color: AppColors.highlight,
            width: 6,
          ),
        };
        _routeLoaded = true;
      });
      await _fitRequestRoute([origin, dest]);
    }
  }

  Set<Marker> _buildRequestMarkers(LatLng origin, LatLng dest) {
    return {
      Marker(
        markerId: const MarkerId('origin'),
        position: origin,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: dest,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
  }

  Future<void> _fitRequestRoute(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;
    final bounds = _boundsFor(points);
    await _mapController!.fitBounds(bounds, padding: 36);
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    if (minLat == maxLat) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if (minLng == maxLng) {
      minLng -= 0.002;
      maxLng += 0.002;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _openDestinationInMaps() async {
    final lat = _trip.destinationLat;
    final lng = _trip.destinationLng;
    final label = Uri.encodeComponent(_trip.destination);
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    final googleUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    var openedGeo = false;
    try {
      openedGeo = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      openedGeo = false;
    }
    if (openedGeo) return;
    var openedGoogle = false;
    try {
      openedGoogle = await launchUrl(
        googleUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      openedGoogle = false;
    }
    if (!openedGoogle && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o mapa.')),
      );
    }
  }

  Future<void> _accept() async {
    final driverProfileId = AuthState.driverProfileId;

    bool ok;
    if (_isScheduledDirectRequest) {
      final offeredPrice = _resolveOfferedPrice();
      if (offeredPrice == null) {
        setState(() => _priceError = true);
        return;
      }
      setState(() => _isLoading = true);
      try {
        await _scheduledDirectRepository.acceptWithPrice(
          _trip.tripId,
          offeredPrice,
        );
        ok = true;
      } catch (_) {
        ok = false;
      }
    } else if (_trip.status == 'searching_drivers') {
      if (driverProfileId == null) return;
      final offeredPrice = _resolveOfferedPrice();
      if (offeredPrice == null) {
        setState(() => _priceError = true);
        return;
      }
      setState(() => _isLoading = true);
      ok = await _tripService.acceptCandidate(
        _trip.tripId,
        driverProfileId,
        offeredPrice: offeredPrice,
      );
    } else {
      setState(() => _isLoading = true);
      ok = await _tripService.confirmScheduledTrip(
        _trip.tripId,
        _observationController.text.trim().isEmpty
            ? null
            : _observationController.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (_isDriverRecheck
                    ? 'Agendamento confirmado!'
                    : 'Corrida aceita com sucesso!')
              : 'Erro ao aceitar corrida',
        ),
        backgroundColor: ok ? const Color(0xFF2ECC71) : Colors.red.shade400,
      ),
    );
    if (ok) context.pop();
  }

  double? _resolveOfferedPrice() {
    if (_trip.kzProposalLocked && _trip.kzProposedPrice != null) {
      return _trip.kzProposedPrice;
    }
    final text = _priceController.text.trim().replaceAll(',', '.');
    final price = double.tryParse(text);
    if (price == null || price <= 0) return null;
    return price;
  }

  Future<void> _reject() async {
    if (!_isScheduledDirectRequest &&
        _observationController.text.trim().isEmpty) {
      setState(() => _observationError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Informe o motivo da recusa na observação'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final driverProfileId = AuthState.driverProfileId;
    late final bool ok;
    if (_isScheduledDirectRequest) {
      try {
        await _scheduledDirectRepository.reject(_trip.tripId);
        ok = true;
      } catch (_) {
        ok = false;
      }
    } else if (_trip.status == 'searching_drivers' && driverProfileId != null) {
      ok = await _tripService.rejectCandidate(
        _trip.tripId,
        driverProfileId,
        observation: _observationController.text.trim(),
      );
    } else {
      ok = await _tripService.rejectTrip(
        _trip.tripId,
        _observationController.text.trim(),
        driverProfileId: driverProfileId,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Corrida recusada' : 'Erro ao recusar corrida'),
        backgroundColor: ok ? Colors.red.shade400 : Colors.orange,
      ),
    );
    if (ok) context.pop();
  }

  Future<void> _openChat() async {
    final userId = AuthState.userId;
    final clientId = _trip.clientId;
    if (userId == null || clientId == null || clientId.isEmpty) return;
    try {
      final roomId = await TripChatService().getOrCreateChatRoom(
        tripId: _trip.tripId,
        clientId: clientId,
        providerId: userId,
      );
      if (roomId == null || !mounted) return;
      context.push(
        '/chat/$roomId',
        extra: ChatPageArgs(
          roomId: roomId,
          title: 'Corrida agendada',
          subtitle: '${_trip.origin} → ${_trip.destination}',
          clientName: _trip.clientName,
          clientAvatarUrl: _trip.clientAvatarUrl,
          clientId: clientId,
          tripId: _trip.tripId,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o chat.')),
      );
    }
  }

  Future<void> _showPhoneActions(String phone) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Contato do cliente',
                  style: TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  normalizedPhone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _PhoneActionTile(
                  icon: Icons.phone_outlined,
                  color: const Color(0xFF2ECC71),
                  title: 'Ligar',
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(_callPhone(normalizedPhone));
                  },
                ),
                _PhoneActionTile(
                  icon: Icons.content_copy_rounded,
                  color: AppColors.secondary,
                  title: 'Copiar número',
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(_copyPhone(normalizedPhone));
                  },
                ),
                _PhoneActionTile(
                  icon: Icons.chat_outlined,
                  color: const Color(0xFF25D366),
                  title: 'WhatsApp',
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(_openWhatsApp(normalizedPhone));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _callPhone(String phone) async {
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

  Future<void> _copyPhone(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Número copiado.')));
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final whatsappPhone = digits.startsWith('55') ? digits : '55$digits';
    final uri = Uri.parse('https://wa.me/$whatsappPhone');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  Future<void> _editOfferedPrice() async {
    if (_trip.status != 'searching_drivers') {
      _showPriceNotEditableError();
      return;
    }
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null) return;

    final controller = TextEditingController(
      text: (_trip.offeredPrice ?? _trip.price)
          .toStringAsFixed(2)
          .replaceAll('.', ','),
    );
    var showError = false;
    final newPrice = await showDialog<double>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Editar valor',
                style: TextStyle(
                  fontFamily: 'OutfitBlack',
                  color: AppColors.textPrimary,
                ),
              ),
              content: TextField(
                key: const Key('edit_offered_price_input'),
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  prefixText: 'R\$  ',
                  hintText: '0,00',
                  errorText: showError ? 'Informe um valor válido' : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.highlight,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim().replaceAll(',', '.');
                    final value = double.tryParse(text);
                    if (value == null || value <= 0) {
                      setDialogState(() => showError = true);
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.highlight,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (newPrice == null) return;

    setState(() => _isLoading = true);
    final result = await _tripService.updateCandidateOfferedPrice(
      tripId: _trip.tripId,
      driverProfileId: driverProfileId,
      offeredPrice: newPrice,
      candidateId: _trip.candidateId,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case CandidatePriceUpdateResult.success:
        setState(() {
          _currentTrip = _trip.copyWith(offeredPrice: newPrice);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valor atualizado com sucesso.')),
        );
      case CandidatePriceUpdateResult.notEditable:
        _showPriceNotEditableError();
      case CandidatePriceUpdateResult.failure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não foi possível atualizar o valor.'),
            backgroundColor: Colors.red.shade400,
          ),
        );
    }
  }

  void _showPriceNotEditableError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não é possivel editar o valor de uma corrida que ja foi aceita pela KZ, favor acionar suporte',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(_trip.originLat, _trip.originLng);
    final dest = LatLng(_trip.destinationLat, _trip.destinationLng);
    final date = _trip.scheduledAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (widget.fromHome) {
      return _buildRequestScaffold(
        origin: origin,
        dest: dest,
        dateStr: dateStr,
        timeStr: timeStr,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _pageTitle,
          style: const TextStyle(
            fontFamily: 'OutfitBlack',
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Chat com a KZ',
            onPressed: () => context.push('/support-chat'),
            icon: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.fromHome) ...[
                    // Mapa
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 180,
                        child: KzMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              (origin.latitude + dest.latitude) / 2,
                              (origin.longitude + dest.longitude) / 2,
                            ),
                            zoom: 11,
                          ),
                          style: MapStyles.standard,
                          markers: {
                            Marker(
                              markerId: const MarkerId('origin'),
                              position: origin,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueGreen,
                              ),
                            ),
                            Marker(
                              markerId: const MarkerId('dest'),
                              position: dest,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed,
                              ),
                            ),
                          },
                          zoomControlsEnabled: false,
                          scrollGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _StatusChip(trip: _trip),
                  const SizedBox(height: 16),

                  if (_isDriverRecheck) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(
                            0xFFF97316,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.event_available_outlined,
                            size: 20,
                            color: Color(0xFFF97316),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              scheduleDetailRecheckMessage(),
                              style: const TextStyle(
                                fontFamily: 'QuasimodoSemiBold',
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  _SectionCard(
                    title: 'Cliente',
                    icon: Icons.person_outline,
                    children: [
                      _InfoRow(label: 'Nome', value: _trip.clientName),
                      _InfoRow(
                        label: 'Passageiros',
                        value: '${_trip.passengerCount}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Agendamento',
                    icon: Icons.calendar_today_outlined,
                    children: [
                      _InfoRow(label: 'Data', value: dateStr),
                      _InfoRow(label: 'Horário', value: timeStr),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Rota',
                    icon: Icons.route_outlined,
                    children: [
                      _InfoRow(label: 'Origem', value: _trip.origin),
                      ..._trip.stops.map(
                        (stop) => _InfoRow(
                          label: 'Parada ${stop.order}',
                          value: stop.address,
                        ),
                      ),
                      _InfoRow(label: 'Destino', value: _trip.destination),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_trip.hasChildren) ...[
                    _SectionCard(
                      title: 'Crianças',
                      icon: Icons.child_care_outlined,
                      children: [
                        _InfoRow(
                          label: 'Quantidade',
                          value: '${_trip.childrenCount}',
                        ),
                        if (_trip.children.isNotEmpty)
                          _InfoRow(
                            label: 'Detalhes',
                            value: _trip.children
                                .map(
                                  (c) =>
                                      '${c.age} anos${c.needsCarSeat ? ' (cadeirinha)' : ''}',
                                )
                                .join(', '),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_trip.hasLuggage) ...[
                    _SectionCard(
                      title: 'Bagagem',
                      icon: Icons.luggage_outlined,
                      children: [
                        _InfoRow(
                          label: 'Quantidade',
                          value: '${_trip.luggageCount}',
                        ),
                        if (_trip.luggage.isNotEmpty)
                          _InfoRow(
                            label: 'Detalhes',
                            value: _trip.luggage
                                .map((l) => '${l.quantity}x ${l.size}')
                                .join(', '),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  _SectionCard(
                    title: 'Pagamento',
                    icon: Icons.payment_outlined,
                    children: [
                      _InfoRow(
                        label: 'Método',
                        value: _trip.paymentMethodLabel,
                      ),
                      _InfoRow(
                        label: 'Valor estimado',
                        value: 'R\$ ${_trip.price.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (!widget.fromHome && _trip.offeredPrice != null) ...[
                    _buildEditableOfferedPriceCard(),
                    const SizedBox(height: 12),
                  ],

                  if (_trip.observations != null &&
                      _trip.observations!.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Observações do cliente',
                      icon: Icons.note_outlined,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _trip.observations!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_canRespond) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: _observationError
                            ? Border.all(color: Colors.red, width: 1.5)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.edit_note_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Sua observação',
                                style: TextStyle(
                                  fontFamily: 'OutfitBlack',
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (_observationError)
                                const Text(
                                  ' *',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontFamily: 'OutfitBlack',
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _observationController,
                            maxLines: 3,
                            onChanged: (_) {
                              if (_observationError) {
                                setState(() => _observationError = false);
                              }
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'Escreva uma observação (obrigatório ao recusar)',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF7F7F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.highlight,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_trip.status == 'scheduled') _buildStartBar(),
          if (_canRespond) _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildRequestScaffold({
    required LatLng origin,
    required LatLng dest,
    required String dateStr,
    required String timeStr,
  }) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F2),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildRequestHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRequestMap(origin, dest),
                        const SizedBox(height: 18),
                        _buildRequestSummary(dateStr, timeStr),
                        const SizedBox(height: 12),
                        _buildRouteTimeline(),
                        const SizedBox(height: 12),
                        _buildPassengerAndOptions(),
                        if (shouldShowPriceOfferCard(
                          isDriverRecheck: _isDriverRecheck,
                        )) ...[
                          const SizedBox(height: 12),
                          _buildPriceOfferCard(),
                        ],
                        const SizedBox(height: 12),
                        _buildObservationCard(),
                      ],
                    ),
                  ),
                ),
                _buildActionBar(),
              ],
            ),
          ),
          if (!disableAnimations)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _viewportPulse,
                  builder: (context, _) {
                    return _NeonViewportFrame(intensity: _viewportPulse.value);
                  },
                ),
              ),
            )
          else
            const Positioned.fill(
              child: IgnorePointer(child: _NeonViewportFrame(intensity: 0.45)),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        children: [
          _IconButtonSurface(
            icon: Icons.close_rounded,
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheduleDetailHeaderTitle(isDriverRecheck: _isDriverRecheck),
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 22,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  scheduleDetailHeaderSubtitle(
                    isDriverRecheck: _isDriverRecheck,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _IconButtonSurface(
            icon: Icons.support_agent_rounded,
            onTap: () => context.push('/support-chat'),
          ),
          const SizedBox(width: 10),
          _ClientAvatar(
            name: _trip.clientName,
            avatarUrl: _trip.clientAvatarUrl,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestMap(LatLng origin, LatLng dest) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: InkWell(
        onTap: _openDestinationInMaps,
        borderRadius: BorderRadius.circular(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 188,
            width: double.infinity,
            child: Stack(
              children: [
                KzMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      (origin.latitude + dest.latitude) / 2,
                      (origin.longitude + dest.longitude) / 2,
                    ),
                    zoom: 11,
                  ),
                  style: MapStyles.standard,
                  markers: _requestMarkers,
                  polylines: _requestPolylines,
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    final points = _requestPolylines.isNotEmpty
                        ? _requestPolylines.first.points
                        : <LatLng>[origin, dest];
                    unawaited(_fitRequestRoute(points));
                  },
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: _openDestinationInMaps),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _routeLoaded
                              ? Icons.map_outlined
                              : Icons.sync_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Abrir destino no Maps',
                            style: TextStyle(
                              fontFamily: 'OutfitBlack',
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new_rounded,
                          color: AppColors.textSecondary,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestSummary(String dateStr, String timeStr) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.event_rounded,
            label: 'Data',
            value: dateStr,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            icon: Icons.schedule_rounded,
            label: 'Horario',
            value: timeStr,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            icon: Icons.payments_outlined,
            label: 'Base',
            value: _trip.price > 0
                ? 'R\$ ${_trip.price.toStringAsFixed(2)}'
                : '-',
          ),
        ),
      ],
    );
  }

  Widget _buildRouteTimeline() {
    return _SectionCard(
      title: 'Rota da corrida',
      icon: Icons.route_outlined,
      children: [
        _RouteStopRow(
          icon: Icons.radio_button_checked_rounded,
          color: AppColors.highlight,
          label: 'Embarque',
          address: _trip.origin,
        ),
        const _RouteDivider(),
        ..._trip.stops.expand(
          (stop) => [
            _RouteStopRow(
              icon: Icons.add_location_alt_rounded,
              color: AppColors.highlight,
              label: 'Parada ${stop.order}',
              address: stop.address,
            ),
            const _RouteDivider(),
          ],
        ),
        if (_trip.isRoundTrip) ...[
          _RouteStopRow(
            icon: Icons.sync_alt_rounded,
            color: AppColors.secondary,
            label: 'Retorno',
            address: _trip.returnAt == null
                ? 'Corrida de ida e volta'
                : 'Retorno previsto em ${_formatShortDateTime(_trip.returnAt!)}',
          ),
          const _RouteDivider(),
        ],
        _RouteStopRow(
          icon: Icons.location_on_rounded,
          color: AppColors.secondary,
          label: 'Destino',
          address: _trip.destination,
        ),
      ],
    );
  }

  Widget _buildPassengerAndOptions() {
    final chips = <Widget>[
      _DetailChip(
        icon: Icons.people_outline_rounded,
        label: '${_trip.passengerCount} passageiro(s)',
      ),
      if (_trip.hasChildren)
        _DetailChip(
          icon: Icons.child_care_rounded,
          label: '${_trip.childrenCount} criança(s)',
        ),
      if (_trip.hasLuggage)
        _DetailChip(
          icon: Icons.luggage_rounded,
          label: '${_trip.luggageCount} bagagem',
        ),
      if (_trip.paymentMethod != null)
        _DetailChip(
          icon: Icons.credit_card_rounded,
          label: _trip.paymentMethodLabel,
        ),
    ];

    return _SectionCard(
      title: 'Passageiro e detalhes',
      icon: Icons.person_outline,
      children: [
        _InfoRow(label: 'Cliente', value: _trip.clientName),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
        if (_trip.children.isNotEmpty) ...[
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Crianças',
            value: _trip.children
                .map(
                  (c) =>
                      '${c.age} anos${c.needsCarSeat ? ' com cadeirinha' : ''}',
                )
                .join(', '),
          ),
        ],
        if (_trip.luggage.isNotEmpty) ...[
          const SizedBox(height: 6),
          _InfoRow(
            label: 'Bagagem',
            value: _trip.luggage
                .map((l) => '${l.quantity}x ${l.size}')
                .join(', '),
          ),
        ],
        if (_trip.observations != null && _trip.observations!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _trip.observations!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditableOfferedPriceCard() {
    final value = _trip.offeredPrice ?? _trip.price;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.highlight.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.highlight.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sell_outlined,
              color: AppColors.textPrimary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seu valor',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _editOfferedPrice,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(
                color: AppColors.highlight.withValues(alpha: 0.7),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceOfferCard() {
    final hasKzProposal =
        _trip.kzProposalLocked && _trip.kzProposedPrice != null;
    final isEditable = isPriceOfferEditable(isDriverRecheck: _isDriverRecheck);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _priceError
              ? Colors.red.shade400
              : AppColors.highlight.withValues(alpha: 0.36),
          width: _priceError ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.highlight.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sell_outlined,
                size: 19,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                _isDriverRecheck
                    ? 'Valor confirmado pelo cliente'
                    : 'Seu valor para esta corrida',
                style: const TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('request_price_input'),
            controller: _priceController,
            enabled: isEditable && !hasKzProposal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) {
              if (_priceError) setState(() => _priceError = false);
            },
            decoration: InputDecoration(
              prefixText: 'R\$  ',
              hintText: '0,00',
              helperText: _isDriverRecheck
                  ? 'Valor ja definido na confirmacao do cliente'
                  : hasKzProposal
                  ? 'Proposta feita pela KZ'
                  : 'Obrigatório para enviar sua proposta',
              errorText: _priceError
                  ? 'Informe um valor antes de aceitar'
                  : null,
              filled: true,
              fillColor: (!isEditable || hasKzProposal)
                  ? Colors.grey.shade200
                  : const Color(0xFFFAFAFA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.highlight,
                  width: 1.6,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF16A34A),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationCard() {
    return _SectionCard(
      title: 'Observação para recusa',
      icon: Icons.edit_note_outlined,
      children: [
        TextField(
          controller: _observationController,
          maxLines: 3,
          onChanged: (_) {
            if (_observationError) setState(() => _observationError = false);
          },
          decoration: InputDecoration(
            hintText: 'Obrigatório somente se recusar',
            errorText: _observationError ? 'Informe o motivo da recusa' : null,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF7F7F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.highlight,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Future<void> _startTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar corrida?'),
        content: const Text(
          'Confirme somente quando estiver a caminho do embarque. Esta ação não pode ser desfeita pelo aplicativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    final ok = await _tripService.startTrip(_trip.tripId);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao iniciar viagem'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }
    final activeTripData = ActiveTripData(
      id: _trip.tripId,
      candidateId: '',
      clientName: _trip.clientName,
      clientId: _trip.clientId,
      clientPhone: _trip.clientPhone,
      clientAvatarUrl: _trip.clientAvatarUrl,
      pickupAddress: _trip.origin,
      destinationAddress: _trip.destination,
      pickupLat: _trip.originLat,
      pickupLng: _trip.originLng,
      destinationLat: _trip.destinationLat,
      destinationLng: _trip.destinationLng,
      passengerCount: _trip.passengerCount,
      offeredPrice: _trip.price,
      paymentMethod: _trip.paymentMethod,
      scheduledAt: _trip.scheduledAt,
      status: 'started',
      isRoundTrip: _trip.isRoundTrip,
      executionStage: 'to_pickup',
    );
    if (!mounted) return;
    context.go(
      '/active-trip?tripId=${Uri.encodeComponent(_trip.tripId)}',
      extra: activeTripData,
    );
  }

  void _showCancellationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CancelTripSheet(onConfirm: _requestCancellation),
    );
  }

  Future<void> _requestCancellation(String reason) async {
    final userId = AuthState.userId;
    if (userId == null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _tripCancellationService.requestCancellation(
        tripId: _trip.tripId,
        requestedBy: userId,
        reason: reason,
      );
      if (!mounted) return;
      final draft = Uri.encodeComponent(
        'Olá, preciso cancelar a corrida de ${_trip.origin} para ${_trip.destination}. Motivo informado: $reason',
      );
      context.push('/support-chat?draft=$draft');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível solicitar o cancelamento.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStartBar() {
    final phone = _trip.clientPhone;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 52,
            width: 52,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _showCancellationSheet,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade500,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.cancel_outlined, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 52,
            width: 52,
            child: OutlinedButton(
              onPressed: _openChat,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: BorderSide(color: AppColors.secondary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.chat_outlined, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          if (phone != null && phone.isNotEmpty) ...[
            SizedBox(
              height: 52,
              width: 52,
              child: OutlinedButton(
                onPressed: () => _showPhoneActions(phone),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2ECC71),
                  side: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.phone_outlined, size: 22),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Iniciar corrida',
                        style: TextStyle(
                          fontFamily: 'OutfitBlack',
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _reject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  side: BorderSide(color: Colors.red.shade400, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Recusar',
                  style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isDriverRecheck ? 'Confirmar agendamento' : 'Aceitar',
                        style: const TextStyle(
                          fontFamily: 'OutfitBlack',
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatShortDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month às $hour:$minute';
}

class _IconButtonSurface extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButtonSurface({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.textPrimary, size: 24),
        ),
      ),
    );
  }
}

class _PhoneActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _PhoneActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _ClientAvatar({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasAvatar = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.highlight.withValues(alpha: 0.16),
      backgroundImage: hasAvatar ? NetworkImage(url) : null,
      child: hasAvatar
          ? null
          : Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(
                fontFamily: 'OutfitBlack',
                fontSize: 20,
                color: AppColors.highlight,
              ),
            ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.highlight),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStopRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String address;

  const _RouteStopRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.28,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteDivider extends StatelessWidget {
  const _RouteDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
      child: Container(
        width: 2,
        height: 22,
        color: AppColors.highlight.withValues(alpha: 0.26),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonViewportFrame extends StatelessWidget {
  final double intensity;

  const _NeonViewportFrame({required this.intensity});

  @override
  Widget build(BuildContext context) {
    final alpha = 0.38 + (intensity * 0.30);
    final blur = 18.0 + (intensity * 22);
    final spread = 1.5 + (intensity * 4);
    final thickness = 5.0 + (intensity * 3);
    final color = AppColors.highlight.withValues(alpha: alpha);
    final glow = BoxShadow(
      color: AppColors.highlight.withValues(alpha: 0.24 + (intensity * 0.22)),
      blurRadius: blur,
      spreadRadius: spread,
    );

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: thickness,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, boxShadow: [glow]),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: thickness,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, boxShadow: [glow]),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: thickness,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, boxShadow: [glow]),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: thickness,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, boxShadow: [glow]),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TripData trip;
  const _StatusChip({required this.trip});

  Color get _color => switch (trip.status) {
    'awaiting_client_confirmation' => Colors.orange,
    'awaiting_driver_confirmation' => const Color(0xFFF97316),
    'scheduled' => const Color(0xFF2ECC71),
    'searching_drivers' => AppColors.secondary,
    _ => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: _color),
          const SizedBox(width: 8),
          Text(
            trip.statusLabel,
            style: TextStyle(
              fontFamily: 'QuasimodoSemiBold',
              fontSize: 13,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'QuasimodoSemiBold',
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
