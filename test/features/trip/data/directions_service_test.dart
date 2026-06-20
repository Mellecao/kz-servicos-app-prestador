import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/directions_service.dart';

void main() {
  test('fetchRoute uses Google Directions and parses route summary', () async {
    Uri? requestedUri;
    final service = DirectionsService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(_googleRouteResponse, 200);
      }),
    );

    final result = await service.fetchRoute(
      origin: const LatLng(-23.561, -46.656),
      destination: const LatLng(-23.627, -46.656),
    );

    expect(requestedUri?.host, 'maps.googleapis.com');
    expect(requestedUri?.path, '/maps/api/directions/json');
    expect(requestedUri?.queryParameters['language'], 'pt-BR');
    expect(result.polyline, hasLength(3));
    expect(result.steps, hasLength(1));
    expect(result.steps.single.instruction, 'Vire à direita na Rua A');
    expect(result.steps.single.distanceText, '300 m');
    expect(result.steps.single.distanceMeters, 300);
    expect(result.distanceText, '7,4 km');
    expect(result.distanceMeters, 7400);
    expect(result.durationText, '18 min');
    expect(result.durationSeconds, 1080);
  });

  test('fetchRoute does not fall back to OSRM when Google fails', () async {
    Uri? requestedUri;
    final service = DirectionsService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response('{"routes":[]}', 200);
      }),
    );

    final result = await service.fetchRoute(
      origin: const LatLng(-23.561, -46.656),
      destination: const LatLng(-23.627, -46.656),
    );

    expect(requestedUri?.host, 'maps.googleapis.com');
    expect(result.polyline, isEmpty);
    expect(result.steps, isEmpty);
  });

  test('empty route has no fallback straight-line polyline', () {
    expect(
      RouteRenderingPoints.fromResult(
        const LatLng(-23.561, -46.656),
        const LatLng(-23.627, -46.656),
        resultPolyline: const [],
      ),
      isEmpty,
    );
  });
}

const _googleRouteResponse = '''
{
  "routes": [
    {
      "overview_polyline": {
        "points": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
      },
      "legs": [
        {
          "distance": {"text": "7,4 km", "value": 7400},
          "duration": {"text": "18 min", "value": 1080},
          "steps": [
            {
              "html_instructions": "Vire à direita na <b>Rua A</b>",
              "maneuver": "turn-right",
              "distance": {"text": "300 m", "value": 300},
              "end_location": {"lat": -23.562, "lng": -46.657}
            }
          ]
        }
      ]
    }
  ]
}
''';
