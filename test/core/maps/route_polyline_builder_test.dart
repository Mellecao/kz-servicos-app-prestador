import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/maps/route_polyline_builder.dart';

void main() {
  test('builds yellow base route and yellow pulse segment', () {
    const route = [
      LatLng(-23.561, -46.656),
      LatLng(-23.600, -46.656),
      LatLng(-23.627, -46.656),
    ];
    const pulse = [LatLng(-23.580, -46.656), LatLng(-23.600, -46.656)];

    final polylines = RoutePolylineBuilder.yellowPulsingRoute(
      routePoints: route,
      pulsePoints: pulse,
      fadeFactor: 1,
    );

    expect(polylines.map((p) => p.polylineId.value), [
      'route_glow',
      'route',
      'pulse_glow',
      'pulse_core',
    ]);
    expect(
      polylines.elementAt(0).color,
      AppColors.highlight.withValues(alpha: 0.18),
    );
    expect(polylines.elementAt(1).color, AppColors.highlight);
    expect(
      polylines.elementAt(2).color,
      AppColors.highlight.withValues(alpha: 0.60),
    );
    expect(polylines.elementAt(3).color, const Color(0xFFFFE08A));
  });
}
