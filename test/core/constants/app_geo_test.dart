import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/core/constants/app_geo.dart';

void main() {
  test('centro padrão do mapa é Luanda', () {
    expect(AppGeo.luanda, const LatLng(-8.8383, 13.2344));
  });

  test('região e idioma das APIs do Google são Angola / pt-PT', () {
    expect(AppGeo.regionCode, 'ao');
    expect(AppGeo.language, 'pt-PT');
  });
}
