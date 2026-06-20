import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

abstract final class RoutePolylineBuilder {
  static Set<Polyline> yellowRoute(List<LatLng> routePoints) {
    if (routePoints.length < 2) return const {};

    return {
      Polyline(
        polylineId: const PolylineId('route_glow'),
        points: routePoints,
        color: AppColors.highlight.withValues(alpha: 0.18),
        width: 10,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: AppColors.highlight,
        width: 4,
      ),
    };
  }

  static Set<Polyline> yellowPulsingRoute({
    required List<LatLng> routePoints,
    required List<LatLng> pulsePoints,
    required double fadeFactor,
  }) {
    return {
      ...yellowRoute(routePoints),
      if (pulsePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('pulse_glow'),
          points: pulsePoints,
          color: AppColors.highlight.withValues(alpha: 0.60 * fadeFactor),
          width: 12,
        ),
      if (pulsePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('pulse_core'),
          points: pulsePoints,
          color: const Color(0xFFFFE08A).withValues(alpha: fadeFactor),
          width: 5,
        ),
    };
  }
}
