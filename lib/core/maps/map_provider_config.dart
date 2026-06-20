enum MapProvider { google }

abstract final class MapProviderConfig {
  static const String providerKey = 'MAP_PROVIDER';
  static const String defaultProviderValue = 'google';

  static final MapProvider current = parse(
    const String.fromEnvironment(
      providerKey,
      defaultValue: defaultProviderValue,
    ),
  );

  static bool get useGoogle => true;
  static bool get useOpenStreetMap => false;

  static MapProvider parse(String value) => MapProvider.google;
}
