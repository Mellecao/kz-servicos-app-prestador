import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/constants/map_styles.dart';

void main() {
  group('MapStyles', () {
    test('normalizes exported style objects to Google Maps legacy rules', () {
      final normalized = MapStyles.normalize('''
{
  "variant": "light",
  "styles": [
    {
      "id": "natural.water",
      "geometry": {
        "fillColor": "#6b6b6b"
      },
      "label": {
        "textFillColor": "#e6e6e6"
      }
    },
    {
      "id": "pointOfInterest",
      "geometry": {
        "visible": false
      }
    }
  ]
}
''');

      final rules = jsonDecode(normalized) as List<dynamic>;

      expect(
        rules,
        contains(
          equals({
            'featureType': 'water',
            'elementType': 'geometry',
            'stylers': [
              {'color': '#6b6b6b'},
            ],
          }),
        ),
      );
      expect(
        rules,
        contains(
          equals({
            'featureType': 'poi',
            'elementType': 'geometry',
            'stylers': [
              {'visibility': 'off'},
            ],
          }),
        ),
      );
    });

    test('keeps legacy style arrays unchanged', () {
      const style = '[{"featureType":"water","stylers":[{"color":"#000000"}]}]';

      expect(MapStyles.normalize(style), style);
    });
  });
}
