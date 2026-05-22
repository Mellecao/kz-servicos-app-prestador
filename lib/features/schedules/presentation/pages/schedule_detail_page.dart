import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';

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

class _ScheduleDetailPageState extends State<ScheduleDetailPage> {
  final _observationController = TextEditingController();
  bool _observationError = false;
  bool _isLoading = false;
  final _tripService = TripService();

  TripData get _trip => widget.trip;

  // Na home: motorista pode responder a qualquer convite pendente.
  // Em agendamentos: só confirma se foi diretamente atribuído e aguarda confirmação.
  bool get _canRespond => widget.fromHome
      ? _trip.canDriverRespond
      : _trip.status == 'awaiting_driver_confirmation';

  String get _pageTitle =>
      widget.fromHome ? 'Detalhes da corrida' : 'Detalhes do agendamento';

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _isLoading = true);

    bool ok;
    if (_trip.status == 'searching_drivers') {
      ok = await _tripService.acceptAvailableTrip(
        _trip.tripId,
        // providerProfileId used as driverProfileId in the DB update
        _trip.tripId, // placeholder — real call uses AuthState
      );
    } else {
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
        content: Text(ok ? 'Corrida aceita com sucesso!' : 'Erro ao aceitar corrida'),
        backgroundColor: ok ? const Color(0xFF2ECC71) : Colors.red.shade400,
      ),
    );
    if (ok) context.pop();
  }

  Future<void> _reject() async {
    if (_observationController.text.trim().isEmpty) {
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
    final ok = await _tripService.rejectTrip(
      _trip.tripId,
      _observationController.text.trim(),
    );

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

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(_trip.originLat, _trip.originLng);
    final dest = LatLng(_trip.destinationLat, _trip.destinationLng);
    final date = _trip.scheduledAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

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
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mapa
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 180,
                      child: GoogleMap(
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

                  _StatusChip(trip: _trip),
                  const SizedBox(height: 16),

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
                                .map((c) =>
                                    '${c.age} anos${c.needsCarSeat ? ' (cadeirinha)' : ''}')
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

  Future<void> _startTrip() async {
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
    );
    if (!mounted) return;
    context.push('/active-trip', extra: activeTripData);
  }

  Widget _buildStartBar() {
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
      child: SizedBox(
        width: double.infinity,
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
                  style: TextStyle(fontFamily: 'OutfitBlack', fontSize: 15),
                ),
        ),
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
                    : const Text(
                        'Aceitar',
                        style: TextStyle(
                            fontFamily: 'OutfitBlack', fontSize: 15),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TripData trip;
  const _StatusChip({required this.trip});

  Color get _color => switch (trip.status) {
        'awaiting_client_confirmation' => Colors.orange,
        'awaiting_driver_confirmation' => AppColors.secondary,
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
