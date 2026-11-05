import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/utils/kz_format.dart';

class PendingTripRequestsCarousel extends StatefulWidget {
  final List<TripData> trips;
  final String selectedTripId;
  final ValueChanged<TripData> onTripTap;
  final ValueChanged<TripData> onTripChanged;

  const PendingTripRequestsCarousel({
    super.key,
    required this.trips,
    required this.selectedTripId,
    required this.onTripTap,
    required this.onTripChanged,
  });

  @override
  State<PendingTripRequestsCarousel> createState() =>
      _PendingTripRequestsCarouselState();
}

class _PendingTripRequestsCarouselState
    extends State<PendingTripRequestsCarousel> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = _selectedIndex;
    _pageController = PageController(initialPage: _currentPage);
    _pageController.addListener(_handlePageChange);
  }

  int get _selectedIndex {
    final index = widget.trips.indexWhere(
      (trip) => trip.tripId == widget.selectedTripId,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(covariant PendingTripRequestsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _selectedIndex;
    if (nextIndex != _currentPage) {
      _currentPage = nextIndex;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _handlePageChange() {
    final page = _pageController.page?.round() ?? 0;
    if (page == _currentPage || page < 0 || page >= widget.trips.length) {
      return;
    }
    setState(() => _currentPage = page);
    widget.onTripChanged(widget.trips[page]);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showsPassengerDetails = widget.trips.any(
      (trip) => trip.passengerLabels.isNotEmpty || trip.childLabels.isNotEmpty,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: AppColors.highlight,
                ),
                const SizedBox(width: 8),
                Text(
                  'Solicitações pendentes (${widget.trips.length})',
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: showsPassengerDetails ? 294 : 198,
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.trips.length,
              itemBuilder: (_, index) {
                final trip = widget.trips[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => widget.onTripTap(trip),
                    child: _PendingTripCard(trip: trip),
                  ),
                );
              },
            ),
          ),
          if (widget.trips.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.trips.length, (index) {
                  final active = index == _currentPage;
                  return AnimatedContainer(
                    key: ValueKey('pending_trip_dot_$index'),
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.highlight
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingTripCard extends StatelessWidget {
  final TripData trip;

  const _PendingTripCard({required this.trip});

  bool get _isDriverConfirmation => trip.isDriverRecheck;

  @override
  Widget build(BuildContext context) {
    final date = trip.scheduledAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final price =
        trip.kzProposedPrice ?? trip.offeredPrice ?? trip.estimatedPrice;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.highlight.withValues(alpha: 0.12),
                child: Text(
                  trip.clientName.isNotEmpty ? trip.clientName[0] : '?',
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 14,
                    color: AppColors.highlight,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  trip.clientName,
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CompactInfoPill(
                icon: Icons.schedule_rounded,
                label: '$dateStr às $timeStr',
              ),
              if (_isDriverConfirmation)
                const _CompactBadge(label: 'Confirmação pendente')
              else
                const _CompactBadge(label: 'Nova solicitação'),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),
          _RouteLine(color: const Color(0xFF27AE60), label: trip.origin),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(width: 2, height: 14, color: Colors.grey.shade300),
          ),
          _RouteLine(color: Colors.red.shade400, label: trip.destination),
          if (trip.passengerLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CompactDetailSection(
              title: 'Passageiros',
              entries: trip.passengerLabels,
            ),
          ],
          if (trip.childLabels.isNotEmpty) ...[
            const SizedBox(height: 6),
            _CompactDetailSection(
              title: 'Crianças',
              entries: trip.childLabels,
              warning: true,
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Text(
                trip.paymentMethodLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (price != null)
                Text(
                  formatKz(price),
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 16,
                    color: Color(0xFF27AE60),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactDetailSection extends StatelessWidget {
  final String title;
  final List<String> entries;
  final bool warning;

  const _CompactDetailSection({
    required this.title,
    required this.entries,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFB45309) : AppColors.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            entries.join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color, height: 1.2),
          ),
        ),
      ],
    );
  }
}

class _CompactBadge extends StatelessWidget {
  final String label;

  const _CompactBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF97316),
        ),
      ),
    );
  }
}

class _CompactInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CompactInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  final Color color;
  final String label;

  const _RouteLine({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
