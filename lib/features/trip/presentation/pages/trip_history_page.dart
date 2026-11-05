import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/core/utils/kz_format.dart';
import 'package:kz_servicos_prestador/core/constants/app_locale.dart';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key});

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  final _tripService = TripService();
  List<TripData> _all = [];
  bool _loading = true;
  String _activeFilter = 'Todas';
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profileId = AuthState.providerProfileId ?? '';
    final trips = await _tripService.getDriverTripHistory(profileId);
    if (mounted) {
      setState(() {
        _all = trips;
        _loading = false;
      });
    }
  }

  List<TripData> get _filteredTrips {
    final now = DateTime.now();
    return switch (_activeFilter) {
      'Este mês' =>
        _all
            .where(
              (t) =>
                  (t.finishedAt ?? t.scheduledAt).month == now.month &&
                  (t.finishedAt ?? t.scheduledAt).year == now.year,
            )
            .toList(),
      'Período' =>
        _customRange != null
            ? _all.where((t) {
                final d = t.finishedAt ?? t.scheduledAt;
                return !d.isBefore(
                      _customRange!.start.subtract(const Duration(days: 1)),
                    ) &&
                    d.isBefore(_customRange!.end.add(const Duration(days: 1)));
              }).toList()
            : _all,
      _ => _all,
    };
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: AppLocale.locale,
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _activeFilter = 'Período';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final filtered = _filteredTrips;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Histórico de viagens',
          style: TextStyle(
            fontFamily: 'OutfitBlack',
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: ['Todas', 'Este mês', 'Período'].map((f) {
                final isActive = f == _activeFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: f == 'Período'
                        ? _pickDateRange
                        : () => setState(() => _activeFilter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.highlight : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isActive
                            ? null
                            : Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        f == 'Período' && _customRange != null
                            ? '${_customRange!.start.day}/${_customRange!.start.month} – ${_customRange!.end.day}/${_customRange!.end.month}'
                            : f,
                        style: TextStyle(
                          fontFamily: 'QuasimodoSemiBold',
                          fontSize: 13,
                          color: isActive
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma viagem encontrada',
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
                        16,
                        8,
                        16,
                        bottomPadding + 16,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _TripHistoryCard(
                        trip: filtered[i],
                        onTap: () => context.push(
                          '/trip-history-detail',
                          extra: filtered[i],
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

class _TripHistoryCard extends StatelessWidget {
  final TripData trip;
  final VoidCallback onTap;

  const _TripHistoryCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final completedAt = trip.finishedAt ?? trip.scheduledAt;
    final dateStr =
        '${completedAt.day.toString().padLeft(2, '0')}/${completedAt.month.toString().padLeft(2, '0')}/${completedAt.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                Text(
                  formatKz(trip.price),
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 15,
                    color: Color(0xFF2ECC71),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2ECC71),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.origin,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade400, width: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.destination,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 13,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (trip.rating != null) ...[
                  const Spacer(),
                  const Icon(Icons.star, size: 13, color: AppColors.highlight),
                  const SizedBox(width: 2),
                  Text(
                    trip.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
