# OpenStreetMap Provider Design

## Goal

Make this app use OpenStreetMap-based map display and routing by default, while keeping Google Maps available through one build-time switch.

## Decisions

- The provider is selected with `--dart-define=MAP_PROVIDER=openstreetmap` or `--dart-define=MAP_PROVIDER=google`.
- OpenStreetMap is the default provider in this repository.
- Existing trip and schedule address fields stay unchanged. This app currently reads formatted addresses and coordinates from Supabase/mock data; it does not actively call Google Places or Geocoding.
- The map UI moves behind a small adapter so screens do not need to know whether the active renderer is Google Maps or OpenStreetMap.
- OpenStreetMap rendering uses `flutter_map` with OSM raster tiles. Routing uses OSRM's route API for OSM mode.
- Google Maps rendering and Google Directions remain available for quick rollback.

## Reversal

Run with:

```powershell
flutter run --dart-define=MAP_PROVIDER=google
```

To return to OpenStreetMap:

```powershell
flutter run --dart-define=MAP_PROVIDER=openstreetmap
```

On web, Google Maps also needs the page to load the Google script. Use `?mapProvider=google` or set `localStorage.MAP_PROVIDER = 'google'` before loading the app.

## Risks

- Public OSM tile servers are not meant for high-volume commercial production traffic. The adapter keeps the tile URL centralized so a dedicated tile provider can be swapped later.
- The OSRM public demo server is suitable for development and low-volume testing. Production should use an owned OSRM instance or a paid OSM-based routing provider.
- OSM rendering will not exactly match the previous Google custom style or tilt behavior.
