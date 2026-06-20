# OpenStreetMap Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch this Flutter app to OpenStreetMap map display and routing by default, with Google Maps still available through `MAP_PROVIDER=google`.

**Architecture:** Introduce a central provider config and map adapter. Existing screens keep using Google Maps value types such as `LatLng`, `Marker`, and `Polyline`, while the adapter renders either Google Maps or `flutter_map`.

**Tech Stack:** Flutter, google_maps_flutter, flutter_map, latlong2, http, OSRM route API.

---

### Task 1: Provider Configuration

**Files:**
- Create: `lib/core/maps/map_provider_config.dart`
- Test: `test/core/maps/map_provider_config_test.dart`

- [ ] Write tests for default provider, Google parsing, OpenStreetMap parsing, and fallback.
- [ ] Implement `MapProviderConfig` with `String.fromEnvironment('MAP_PROVIDER', defaultValue: 'openstreetmap')`.
- [ ] Run `flutter test test/core/maps/map_provider_config_test.dart`.

### Task 2: OSRM Routing

**Files:**
- Modify: `lib/features/trip/data/services/directions_service_mobile.dart`
- Modify: `lib/features/trip/data/services/directions_service_web.dart`
- Test: `test/features/trip/data/directions_service_test.dart`

- [ ] Write a failing test that verifies OSM mode calls `router.project-osrm.org` and parses route geometry and steps.
- [ ] Add OSRM request/response parsing for OpenStreetMap mode.
- [ ] Preserve the current Google Directions code path for Google mode.
- [ ] Run `flutter test test/features/trip/data/directions_service_test.dart`.

### Task 3: Map Adapter

**Files:**
- Create: `lib/core/maps/kz_map.dart`
- Modify: `pubspec.yaml`

- [ ] Add `flutter_map` and `latlong2`.
- [ ] Implement `KzMap` with Google and OpenStreetMap renderers.
- [ ] Implement `KzMapController.animateTo` and `KzMapController.fitBounds`.
- [ ] Render OSM markers and polylines by converting existing Google Maps value types.

### Task 4: Screen Migration

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`
- Modify: `lib/features/trip/presentation/pages/active_trip_page.dart`
- Modify: `lib/features/trip/presentation/pages/trip_history_detail_page.dart`
- Modify: `lib/features/schedules/presentation/pages/schedule_detail_page.dart`

- [ ] Replace direct `GoogleMap` widgets with `KzMap`.
- [ ] Replace direct `GoogleMapController` calls with `KzMapController`.
- [ ] Keep existing markers, polylines, route pulse, and phase behavior intact.

### Task 5: Web Google Script Gating and Docs

**Files:**
- Modify: `web/index.html`
- Modify: `README.md`

- [ ] Stop loading Google Maps JavaScript by default.
- [ ] Load the script only when the web page provider is Google.
- [ ] Document OpenStreetMap default and Google rollback commands.

### Task 6: Verification

**Files:**
- All touched files

- [ ] Run targeted tests.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test` if dependency resolution and existing tests allow it.
