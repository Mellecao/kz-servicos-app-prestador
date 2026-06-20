# kz_servicos_prestador

A new Flutter project.

## Map provider

The app defaults to Google Maps rendering and Google Directions routing:

    flutter run

To temporarily use OpenStreetMap rendering and OSRM routing:

    flutter run --dart-define=MAP_PROVIDER=openstreetmap

On web, Google Maps is loaded by default. Open the app with
?mapProvider=openstreetmap or set localStorage.MAP_PROVIDER = 'openstreetmap'
before loading it to skip the Google Maps JavaScript loader.

For OpenStreetMap usage, replace the centralized tile URL in
lib/core/maps/kz_map.dart and the OSRM endpoint in
lib/features/trip/data/services/directions_service_mobile.dart with owned or
paid infrastructure suitable for the expected traffic.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
