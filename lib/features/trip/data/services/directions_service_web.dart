import 'dart:js_interop';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/google_maps_js_types.dart';

class DirectionsService {
  final JsDirectionsSvc _service = JsDirectionsSvc();

  DirectionsService({dynamic client});

  Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    final request = <String, Object>{
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
    }.jsify() as JSObject;

    try {
      final response = await _service.route(request).toDart;
      final routes = response.routes.toDart;
      if (routes.isEmpty) return RouteResult.empty;

      final path = routes[0].overviewPath.toDart;
      final points =
          path.map((p) => LatLng(p.lat(), p.lng())).toList();
      // TODO(web): parse turn-by-turn steps from JS Directions API response
      return RouteResult(polyline: points, steps: const []);
    } catch (_) {
      return RouteResult.empty;
    }
  }
}
