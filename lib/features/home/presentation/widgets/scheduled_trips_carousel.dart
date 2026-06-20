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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          SizedBox(
            height: 178,
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
      'awaiting_driver_confirmation' => const Color(0xFFF97316),
      'scheduled' => const Color(0xFF27AE60),
      _ => AppColors.textSecondary,
    };
  }

  Color get _statusBg {
    if (trip.isAwaitingKzApproval) return const Color(0xFFFFF3E0);
    return switch (trip.status) {
      'awaiting_client_confirmation' => AppColors.secondary.withValues(
        alpha: 0.1,
      ),
      'awaiting_driver_confirmation' => const Color(0xFFFFF3E0),
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
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: nome + badge de status
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                backgroundImage:
                    trip.clientAvatarUrl != null &&
                        trip.clientAvatarUrl!.isNotEmpty
                    ? NetworkImage(trip.clientAvatarUrl!)
                    : null,
                child:
                    trip.clientAvatarUrl == null ||
                        trip.clientAvatarUrl!.isEmpty
                    ? Text(
                        trip.clientName.isNotEmpty ? trip.clientName[0] : '?',
                        style: const TextStyle(
                          fontFamily: 'OutfitBlack',
                          fontSize: 14,
                          color: AppColors.secondary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  trip.clientName,
                  style: const TextStyle(
                    fontFamily: 'OutfitBlack',
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 170),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trip.statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Subtítulo: data · hora · pax  +  preço
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$dateStr · $timeStr · ${trip.passengerCount} pax',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'R\$ ${trip.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'OutfitBlack',
                  fontSize: 16,
                  color: Color(0xFF27AE60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 9),
          // Rota: origem → destino
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 12,
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF27AE60),
                      ),
                    ),
                    Container(
                      width: 1.5,
                      height: 13,
                      color: Colors.grey.shade300,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.origin,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      trip.destination,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trip.paymentMethod != null || trip.hasLuggage) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 6),
            Row(
              children: [
                if (trip.paymentMethod != null)
                  Text(
                    '💳 ${trip.paymentMethodLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (trip.paymentMethod != null && trip.hasLuggage)
                  const Text(
                    '  ·  ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (trip.hasLuggage)
                  Text(
                    '👜 ${trip.luggageCount} mala${trip.luggageCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
