import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteStep {
  final String instruction;
  final String distanceText;
  final double distanceMeters;
  final String? maneuver;
  final LatLng endLocation;

  const RouteStep({
    required this.instruction,
    required this.distanceText,
    required this.distanceMeters,
    this.maneuver,
    required this.endLocation,
  });
}

class RouteResult {
  final List<LatLng> polyline;
  final List<RouteStep> steps;

  const RouteResult({required this.polyline, required this.steps});

  static const empty = RouteResult(polyline: [], steps: []);
}
