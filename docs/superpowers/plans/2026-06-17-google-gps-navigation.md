# Google GPS Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace provider-switched maps with Google Maps and upgrade active trip navigation into a GPS-style experience.

**Architecture:** Remove OpenStreetMap dependencies and code paths. Extend Google Directions route data with total distance/duration. Keep active trip navigation in the existing page, adding focused GPS widgets rather than creating a separate flow.

**Tech Stack:** Flutter, google_maps_flutter, Google Directions API, url_launcher, flutter_test.

---

### Task 1: Remove OSM Provider Surface

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/maps/kz_map.dart`
- Modify: `lib/core/maps/map_provider_config.dart`
- Test: `test/core/maps/kz_map_test.dart`
- Test: `test/core/maps/map_provider_config_test.dart`

- [ ] Write failing tests that assume `KzMap` has no provider override and `MapProviderConfig.current` is Google.
- [ ] Run focused map tests and confirm failure.
- [ ] Remove `flutter_map` and `latlong2` dependencies.
- [ ] Simplify `KzMap` to render only `GoogleMap`.
- [ ] Simplify `MapProviderConfig` to Google-only compatibility.
- [ ] Run focused map tests and confirm pass.

### Task 2: Google-Only Directions With Summary

**Files:**
- Modify: `lib/features/trip/data/models/route_result.dart`
- Modify: `lib/features/trip/data/services/directions_service_mobile.dart`
- Modify: `lib/features/trip/data/services/directions_service_web.dart`
- Test: `test/features/trip/data/directions_service_test.dart`

- [ ] Write failing tests for `RouteResult.distanceText`, `durationText`, `distanceMeters`, and `durationSeconds` parsed from Google Directions.
- [ ] Run focused directions tests and confirm failure.
- [ ] Add summary fields to `RouteResult`.
- [ ] Parse Google leg distance/duration into `RouteResult`.
- [ ] Remove OSRM fallback and public OSM route method.
- [ ] Run focused directions tests and confirm pass.

### Task 3: GPS-Style Active Trip UI

**Files:**
- Modify: `lib/features/trip/presentation/pages/active_trip_page.dart`
- Modify: `lib/features/trip/presentation/widgets/navigation_instruction_banner.dart`
- Modify: `lib/features/trip/presentation/helpers/external_nav_helper.dart`
- Test: `test/features/trip/widgets/active_trip_panels_test.dart`

- [ ] Write failing widget tests for top instruction card summary and prominent external navigation button.
- [ ] Run focused widget tests and confirm failure.
- [ ] Update instruction banner to show maneuver, step distance, route duration, and route distance.
- [ ] Add a compass/recenter/mute/external-navigation control cluster in active GPS phases.
- [ ] Make external navigation sheet/actions visually prominent.
- [ ] Run focused widget tests and confirm pass.

### Task 4: Full Verification and Builds

**Files:**
- No source changes expected.

- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
- [ ] Run prestador Android build.
- [ ] Locate cliente app and run its Android build.
