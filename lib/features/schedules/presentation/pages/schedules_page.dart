import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/core/widgets/provider_bottom_nav.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class SchedulesPage extends StatefulWidget {
  final ValueChanged<int> onNavTap;

  const SchedulesPage({super.key, required this.onNavTap});

  @override
  State<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<SchedulesPage> {
  final _tripService = TripService();
  List<TripData> _scheduledTrips = [];
  List<TripData> _invitationTrips = [];
  bool _loading = true;
  String _activeFilter = 'Todos';
  RealtimeChannel? _tripsChannel;

  static const _filters = ['Todos', 'Agendado', 'Aguardando aprovação'];

  @override
  void initState() {
    super.initState();
    _load().then((_) => _subscribeToTrips());
  }

  @override
  void dispose() {
    _tripsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToTrips() {
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null) return;
    _tripsChannel = Supabase.instance.client
        .channel('driver-schedules-$driverProfileId')
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
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_profile_id',
            value: driverProfileId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> _load() async {
    final driverId = AuthState.driverProfileId ?? '';
    final results = await Future.wait([
      _tripService.getDriverScheduledTrips(driverId),
      _tripService.getDriverAcceptedCandidacies(driverId),
    ]);
    if (mounted) {
      setState(() {
        _scheduledTrips = results[0];
        _invitationTrips = results[1];
        _loading = false;
      });
    }
  }

  Future<void> _startTrip(TripData trip) async {
    final ok = await _tripService.startTrip(trip.tripId);
    if (!mounted) return;
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
      id: trip.tripId,
      candidateId: '',
      clientName: trip.clientName,
      clientId: trip.clientId,
      clientPhone: trip.clientPhone,
      pickupAddress: trip.origin,
      destinationAddress: trip.destination,
      pickupLat: trip.originLat,
      pickupLng: trip.originLng,
      destinationLat: trip.destinationLat,
      destinationLng: trip.destinationLng,
      passengerCount: trip.passengerCount,
      offeredPrice: trip.price,
      paymentMethod: trip.paymentMethod,
      scheduledAt: trip.scheduledAt,
    );
    context.push('/active-trip', extra: activeTripData);
  }

  List<TripData> get _filtered {
    final scheduled = _scheduledTrips.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final invitations = _invitationTrips.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return switch (_activeFilter) {
      'Agendado' => scheduled,
      'Aguardando aprovação' => invitations,
      _ => [...scheduled, ...invitations],
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final items = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Text(
                    'Agendamentos',
                    style: TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildFilters(),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum agendamento encontrado',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                    24, 0, 24, bottomPadding + 100),
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) => GestureDetector(
                                  onTap: () => context.push(
                                    '/schedule-detail',
                                    extra: items[i],
                                  ),
                                  child: _ScheduleCard(
                                    trip: items[i],
                                    isHighlighted: items[i].status ==
                                            'scheduled' &&
                                        _activeFilter == 'Todos',
                                    onStartTrip: items[i].status == 'scheduled'
                                        ? () => _startTrip(items[i])
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: bottomPadding + 12,
            left: 24,
            right: 24,
            child: ProviderBottomNav(
              selectedIndex: 1,
              onItemSelected: widget.onNavTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: _filters.map((f) {
          final isActive = f == _activeFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = f),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.highlight : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      isActive ? null : Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    fontFamily: 'QuasimodoSemiBold',
                    fontSize: 12,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final TripData trip;
  final bool isHighlighted;
  final VoidCallback? onStartTrip;

  const _ScheduleCard({
    required this.trip,
    this.isHighlighted = false,
    this.onStartTrip,
  });

  Color get _statusColor {
    if (trip.isAwaitingKzApproval) return const Color(0xFFE65100);
    return switch (trip.status) {
      'awaiting_client_confirmation' => AppColors.secondary,
      'awaiting_driver_confirmation' => AppColors.secondary,
      'searching_drivers' => AppColors.secondary,
      'scheduled' => const Color(0xFF2ECC71),
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = trip.scheduledAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.clientName,
                        style: const TextStyle(
                          fontFamily: 'OutfitBlack',
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        trip.statusLabel,
                        style: TextStyle(
                          fontFamily: 'QuasimodoSemiBold',
                          fontSize: 10,
                          color: _statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _RouteLine(origin: trip.origin, destination: trip.destination),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(timeStr,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(
                      'R\$ ${trip.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 14,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                  ],
                ),
                if (trip.status == 'scheduled') ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: onStartTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Iniciar viagem',
                        style: TextStyle(
                          fontFamily: 'OutfitBlack',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isHighlighted)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: const Color(0xFF2ECC71),
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  final String origin;
  final String destination;
  const _RouteLine({required this.origin, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2ECC71), width: 2),
              ),
            ),
            Container(width: 2, height: 16, color: Colors.grey.shade300),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade400, width: 2),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(origin,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(destination,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
