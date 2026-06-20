import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';

class DirectionsService {
  static const String _apiKey = 'AIzaSyCwDyzjfdpfbRU06n6GwzlqbIj_-xfgLHw';

  final http.Client _client;

  DirectionsService({http.Client? client, Object? provider})
    : _client = client ?? http.Client();

  Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    return _fetchGoogleRoute(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );
  }

  Future<RouteResult> _fetchGoogleRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    final params = <String, String>{
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'key': _apiKey,
      'language': 'pt-BR',
      'mode': 'driving',
    };
    if (waypoints.isNotEmpty) {
      params['waypoints'] = waypoints
          .map((wp) => '${wp.latitude},${wp.longitude}')
          .join('|');
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'X-Android-Package': 'com.kzservicos.kz_servicos_prestador',
          'X-Android-Cert': 'c691533385a5bc73b9d778008a0162cec509dce4',
        },
      );
      debugPrint(
        '[KZ-DIR] status=${response.statusCode} body=${response.body.substring(0, response.body.length.clamp(0, 400))}',
      );
      if (response.statusCode != 200) return RouteResult.empty;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != null && status != 'OK') return RouteResult.empty;

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return RouteResult.empty;

      final route = routes[0] as Map<String, dynamic>;
      final legs = route['legs'] as List?;
      final points = _decodeRoutePoints(route, legs);

      final steps = <RouteStep>[];
      var distanceText = '';
      var distanceMeters = 0.0;
      var durationText = '';
      var durationSeconds = 0;
      if (legs != null && legs.isNotEmpty) {
        final firstLeg = legs[0] as Map<String, dynamic>;
        final legDistance = firstLeg['distance'] as Map<String, dynamic>?;
        final legDuration = firstLeg['duration'] as Map<String, dynamic>?;
        distanceText = legDistance?['text'] as String? ?? '';
        distanceMeters = (legDistance?['value'] as num?)?.toDouble() ?? 0;
        durationText = legDuration?['text'] as String? ?? '';
        durationSeconds = (legDuration?['value'] as num?)?.toInt() ?? 0;

        final rawSteps = firstLeg['steps'] as List;
        for (final s in rawSteps) {
          final step = s as Map<String, dynamic>;
          final endLoc = step['end_location'] as Map<String, dynamic>;
          final distMap = step['distance'] as Map<String, dynamic>;
          steps.add(
            RouteStep(
              instruction: _stripHtml(step['html_instructions'] as String),
              distanceText: distMap['text'] as String,
              distanceMeters: (distMap['value'] as num).toDouble(),
              maneuver: step['maneuver'] as String?,
              endLocation: LatLng(
                (endLoc['lat'] as num).toDouble(),
                (endLoc['lng'] as num).toDouble(),
              ),
            ),
          );
        }
      }

      return RouteResult(
        polyline: points,
        steps: steps,
        distanceText: distanceText,
        distanceMeters: distanceMeters,
        durationText: durationText,
        durationSeconds: durationSeconds,
      );
    } catch (_) {
      return RouteResult.empty;
    }
  }

  String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<LatLng> _decodeRoutePoints(Map<String, dynamic> route, List? legs) {
    final detailed = <LatLng>[];
    if (legs != null) {
      for (final leg in legs.cast<Map<String, dynamic>>()) {
        final rawSteps = (leg['steps'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final step in rawSteps) {
          final encoded =
              (step['polyline'] as Map<String, dynamic>?)?['points'] as String?;
          if (encoded == null || encoded.isEmpty) continue;
          _appendPolyline(detailed, _decodePolyline(encoded));
        }
      }
    }
    if (detailed.length > 2) return detailed;

    final overview =
        (route['overview_polyline'] as Map<String, dynamic>?)?['points']
            as String?;
    return overview == null || overview.isEmpty
        ? const []
        : _decodePolyline(overview);
  }

  void _appendPolyline(List<LatLng> target, List<LatLng> points) {
    for (final point in points) {
      if (target.isNotEmpty &&
          target.last.latitude == point.latitude &&
          target.last.longitude == point.longitude) {
        continue;
      }
      target.add(point);
    }
  }

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
