import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Defaults geográficos: o app opera em Luanda, Angola.
abstract final class AppGeo {
  /// Centro padrão do mapa (Luanda).
  static const LatLng luanda = LatLng(-8.8383, 13.2344);

  /// Região (ccTLD) e idioma enviados às APIs do Google (Directions).
  static const String regionCode = 'ao';
  static const String language = 'pt-PT';
}
