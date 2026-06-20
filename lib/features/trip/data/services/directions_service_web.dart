import 'dart:js_interop';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/google_maps_js_types.dart';

class DirectionsService {
  JsDirectionsSvc? _service;

  DirectionsService({Object? client, Object? provider});

  Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    final service = _service ??= JsDirectionsSvc();
    final request =
        <String, Object>{
              'origin': <String, Object>{
                'lat': origin.latitude,
                'lng': origin.longitude,
              },
              'destination': <String, Object>{
                'lat': destination.latitude,
                'lng': destination.longitude,
              },
              'travelMode': 'DRIVING',
              if (waypoints.isNotEmpty)
                'waypoints': waypoints
                    .map(
                      (wp) => <String, Object>{
                        'location': <String, Object>{
                          'lat': wp.latitude,
                          'lng': wp.longitude,
                        },
                        'stopover': true,
                      },
                    )
                    .toList(),
            }.jsify()
            as JSObject;

    try {
      final response = await service.route(request).toDart;
      final routes = response.routes.toDart;
      if (routes.isEmpty) return RouteResult.empty;

      final route = routes[0];
      final legs = route.legs.toDart;
      final points = _routePoints(route, legs);
      final firstLeg = legs.isEmpty ? null : legs[0];
      return RouteResult(
        polyline: points,
        steps: const [],
        distanceText: firstLeg?.distance?.text ?? '',
        distanceMeters: (firstLeg?.distance?.value ?? 0).toDouble(),
        durationText: firstLeg?.duration?.text ?? '',
        durationSeconds: firstLeg?.duration?.value ?? 0,
      );
    } catch (_) {
      return RouteResult.empty;
    }
  }

  List<LatLng> _routePoints(
    JsDirectionsRoute route,
    List<JsDirectionsLeg> legs,
  ) {
    final points = <LatLng>[];
    for (final leg in legs) {
      for (final step in leg.steps.toDart) {
        _appendPoints(
          points,
          step.path.toDart.map((p) => LatLng(p.lat(), p.lng())),
        );
      }
    }
    if (points.length > 2) return points;
    return route.overviewPath.toDart
        .map((p) => LatLng(p.lat(), p.lng()))
        .toList();
  }

  void _appendPoints(List<LatLng> target, Iterable<LatLng> points) {
    for (final point in points) {
      if (target.isNotEmpty &&
          target.last.latitude == point.latitude &&
          target.last.longitude == point.longitude) {
        continue;
      }
      target.add(point);
    }
  }
}
