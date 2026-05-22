import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';

class DirectionsService {
  static const String _apiKey = 'AIzaSyChT4wSYd-b3fT7xfEvUvmgJ0QfZv7MYSE';

  final http.Client _client;

  DirectionsService({http.Client? client})
      : _client = client ?? http.Client();

  Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    final params = <String, String>{
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'key': _apiKey,
      'language': 'pt-BR',
    };
    if (waypoints.isNotEmpty) {
      params['waypoints'] =
          waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|');
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return RouteResult.empty;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return RouteResult.empty;

      final route = routes[0] as Map<String, dynamic>;
      final polyline = route['overview_polyline']['points'] as String;
      final points = _decodePolyline(polyline);

      final legs = route['legs'] as List?;
      final steps = <RouteStep>[];
      if (legs != null && legs.isNotEmpty) {
        final rawSteps = (legs[0] as Map<String, dynamic>)['steps'] as List;
        for (final s in rawSteps) {
          final step = s as Map<String, dynamic>;
          final endLoc = step['end_location'] as Map<String, dynamic>;
          final distMap = step['distance'] as Map<String, dynamic>;
          steps.add(RouteStep(
            instruction: _stripHtml(step['html_instructions'] as String),
            distanceText: distMap['text'] as String,
            distanceMeters: (distMap['value'] as num).toDouble(),
            maneuver: step['maneuver'] as String?,
            endLocation: LatLng(
              (endLoc['lat'] as num).toDouble(),
              (endLoc['lng'] as num).toDouble(),
            ),
          ));
        }
      }

      return RouteResult(polyline: points, steps: steps);
    } catch (_) {
      return RouteResult.empty;
    }
  }

  String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
