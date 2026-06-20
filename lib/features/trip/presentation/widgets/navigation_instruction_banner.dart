import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';

class NavigationInstructionBanner extends StatelessWidget {
  final RouteStep step;
  final Color phaseColor;
  final String routeDistanceText;
  final String routeDurationText;

  const NavigationInstructionBanner({
    super.key,
    required this.step,
    required this.phaseColor,
    this.routeDistanceText = '',
    this.routeDurationText = '',
  });

  IconData get _arrowIcon => switch (step.maneuver) {
    'turn-right' ||
    'ramp-right' ||
    'fork-right' ||
    'merge-right' => Icons.turn_right,
    'turn-left' ||
    'ramp-left' ||
    'fork-left' ||
    'merge-left' => Icons.turn_left,
    'turn-sharp-right' => Icons.turn_sharp_right,
    'turn-sharp-left' => Icons.turn_sharp_left,
    'turn-slight-right' => Icons.turn_slight_right,
    'turn-slight-left' => Icons.turn_slight_left,
    'uturn-right' || 'uturn-left' => Icons.u_turn_right,
    'roundabout-right' => Icons.roundabout_right,
    'roundabout-left' => Icons.roundabout_left,
    'straight' => Icons.straight,
    _ => Icons.navigation,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: phaseColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_arrowIcon, color: Colors.white, size: 38),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.distanceText,
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.instruction,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (routeDistanceText.isNotEmpty || routeDurationText.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                if (routeDurationText.isNotEmpty)
                  _SummaryChip(
                    icon: Icons.schedule_rounded,
                    label: routeDurationText,
                  ),
                if (routeDurationText.isNotEmpty &&
                    routeDistanceText.isNotEmpty)
                  const SizedBox(width: 8),
                if (routeDistanceText.isNotEmpty)
                  _SummaryChip(
                    icon: Icons.route_rounded,
                    label: routeDistanceText,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'OutfitBlack',
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
