import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/maps/map_provider_config.dart';

void main() {
  group('MapProviderConfig', () {
    test('uses Google by default', () {
      expect(MapProviderConfig.defaultProviderValue, 'google');
      expect(
        MapProviderConfig.parse(MapProviderConfig.defaultProviderValue),
        MapProvider.google,
      );
    });

    test('parses google provider', () {
      expect(MapProviderConfig.parse('google'), MapProvider.google);
      expect(MapProviderConfig.parse('GOOGLE'), MapProvider.google);
    });

    test(
      'treats OpenStreetMap aliases as Google because app is Google-only',
      () {
        expect(MapProviderConfig.parse('openstreetmap'), MapProvider.google);
        expect(MapProviderConfig.parse('osm'), MapProvider.google);
      },
    );

    test('falls back to Google for unknown provider', () {
      expect(MapProviderConfig.parse('mapbox'), MapProvider.google);
    });
  });
}
