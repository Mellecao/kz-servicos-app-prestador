# Google GPS Navigation Design

## Goal

Make the active trip navigation feel like a dedicated GPS app while the driver is going to the passenger or to the destination.

## Decisions

- Google Maps is the only map provider in this app.
- OpenStreetMap and OSRM fallback paths are removed.
- The active trip map uses Google camera tilt, bearing, and close zoom during GPS phases.
- The current home map wrapper remains, but it becomes a Google Maps wrapper instead of a provider switch.

## User Experience

During `navigatingToClient` and `tripInProgress`, the driver sees:

- a tilted turn-by-turn map with the vehicle centered and heading-forward;
- a large top maneuver card with the next turn, instruction, and remaining step distance;
- ETA, remaining route distance, and route duration;
- floating compass, mute, recenter, and external navigation controls;
- a prominent external navigation button for Waze or Google Maps.

Non-navigation phases keep the existing trip panels and completion/payment flow.

## Architecture

- `lib/core/maps/kz_map.dart` renders `GoogleMap` directly.
- `lib/features/trip/data/services/directions_service_mobile.dart` calls Google Directions only.
- `lib/features/trip/data/services/directions_service_web.dart` uses Google Maps JavaScript Directions only.
- `lib/features/trip/data/models/route_result.dart` carries polyline, steps, total distance, and total duration.
- `lib/features/trip/presentation/pages/active_trip_page.dart` owns GPS camera behavior and passes route summary data to UI widgets.
- `lib/features/trip/presentation/widgets/navigation_instruction_banner.dart` becomes the GPS-style top maneuver card.
- `lib/features/trip/presentation/helpers/external_nav_helper.dart` exposes a more visible route picker.

## Testing

Tests cover:

- route summary parsing from Google Directions;
- `KzMap` no longer exposing provider switching;
- active trip GPS UI displaying route summary and prominent external navigation entry points.

## Verification

Run:

- `flutter test`
- `flutter analyze`
- Android build for the prestador app
- Android build for the cliente app after locating its project
