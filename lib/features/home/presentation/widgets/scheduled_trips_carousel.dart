import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';

class ScheduledTripsCarousel extends StatefulWidget {
  final List<TripData> trips;
  final void Function(TripData) onTap;

  const ScheduledTripsCarousel({
    super.key,
    required this.trips,
    required this.onTap,
  });

  @override
  State<ScheduledTripsCarousel> createState() => _ScheduledTripsCarouselState();
}

class _ScheduledTripsCarouselState extends State<ScheduledTripsCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) setState(() => _currentPage = page);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.45),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.trips.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => widget.onTap(widget.trips[i]),
                  child: _TripCard(trip: widget.trips[i]),
                ),
              ),
            ),
            if (widget.trips.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DotsIndicator(
                  count: widget.trips.length,
                  current: _currentPage,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.highlight : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripData trip;

  const _TripCard({required this.trip});

  Color get _statusColor {
    if (trip.isAwaitingKzApproval) return const Color(0xFFE65100);
    return switch (trip.status) {
      'awaiting_client_confirmation' => AppColors.secondary,
      'scheduled' => const Color(0xFF27AE60),
      _ => AppColors.textSecondary,
    };
  }

  Color get _statusBg {
    if (trip.isAwaitingKzApproval) return const Color(0xFFFFF3E0);
    return switch (trip.status) {
      'awaiting_client_confirmation' =>
        AppColors.secondary.withValues(alpha: 0.1),
      'scheduled' => const Color(0xFF27AE60).withValues(alpha: 0.1),
      _ => Colors.grey.shade100,
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = trip.scheduledAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.clientName,
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr · $timeStr · ${trip.passengerCount} pax',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trip.statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'R\$ ${trip.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'OutfitBlack',
                      fontSize: 13,
                      color: Color(0xFF27AE60),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF27AE60), width: 2),
                    ),
                  ),
                  Container(
                      width: 1.5, height: 14, color: Colors.grey.shade300),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.red.shade400, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.origin,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trip.destination,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trip.paymentMethod != null || trip.hasLuggage) ...[
            const SizedBox(height: 6),
            const Divider(height: 1, color: Color(0xFFF5F5F5)),
            const SizedBox(height: 5),
            Row(
              children: [
                if (trip.paymentMethod != null)
                  Text(
                    '💳 ${trip.paymentMethodLabel}',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                  ),
                if (trip.paymentMethod != null && trip.hasLuggage)
                  const Text('  ·  ',
                      style: TextStyle(
                          fontSize: 9, color: AppColors.textSecondary)),
                if (trip.hasLuggage)
                  Text(
                    '👜 ${trip.luggageCount} mala${trip.luggageCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
