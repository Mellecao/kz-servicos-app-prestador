import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';

class NavigationInstructionBanner extends StatelessWidget {
  final RouteStep step;
  final Color phaseColor;

  const NavigationInstructionBanner({
    super.key,
    required this.step,
    required this.phaseColor,
  });

  IconData get _arrowIcon => switch (step.maneuver) {
        'turn-right' || 'ramp-right' || 'fork-right' || 'merge-right' =>
          Icons.turn_right,
        'turn-left' || 'ramp-left' || 'fork-left' || 'merge-left' =>
          Icons.turn_left,
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: phaseColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_arrowIcon, color: phaseColor, size: 28),
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
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.instruction,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
