# Trip Request Surface Split and Navigation Zoom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show incoming trip requests as a full-screen flow when the driver is not in an active trip, keep the compact card only for the in-trip context, and increase the 3D navigation zoom during pickup and in-trip navigation.

**Architecture:** `HomePage` becomes the entry point for request routing decisions. It uses the existing `tripRequestId` query parameter to push a request detail surface immediately when the driver is not on an active trip, while `TripRequestCard` keeps the compact overlay behavior for the in-trip use case. `ActiveTripPage` only changes camera presets, keeping the route drawing and phase logic intact.

**Tech Stack:** Flutter, GoRouter, Supabase realtime, Google Maps Flutter, widget tests.

---

### Task 1: Open full-screen request flow from HomePage

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`
- Modify: `lib/routes/app_router.dart`
- Test: `test/features/home/widgets/trip_request_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('tripRequestId opens full-screen request details instead of compact card', (tester) async {
  // Build HomePage with a tripRequestId query parameter and a pending request.
  // Expect the page to navigate to the detail surface and not keep the compact card visible.
});
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/home/widgets/trip_request_card_test.dart`
Expected: the new request-surface test fails because HomePage ignores `tripRequestId`.

- [ ] **Step 3: Implement the routing behavior**

```dart
class HomePage extends StatefulWidget {
  final ValueChanged<int> onNavTap;
  final String? tripRequestId;

  const HomePage({
    super.key,
    required this.onNavTap,
    this.tripRequestId,
  });
}

// In the router:
HomePage(
  onNavTap: (i) => _handleNavTap(context, state, i),
  tripRequestId: state.uri.queryParameters['tripRequestId'],
)
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/home/widgets/trip_request_card_test.dart`
Expected: new request-surface test passes once HomePage opens the full-screen request route.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/pages/home_page.dart lib/routes/app_router.dart test/features/home/widgets/trip_request_card_test.dart
git commit -m "feat(home): abre solicitação de corrida em tela cheia"
```

### Task 2: Keep TripRequestCard compact and hide the details action when requested

**Files:**
- Modify: `lib/features/home/presentation/widgets/trip_request_card.dart`
- Modify: `test/features/home/widgets/trip_request_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('compact mode hides details button', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TripRequestCard(
          request: _mockTrip,
          onAccept: (_) {},
          onReject: () {},
          onShowDetails: () {},
          showDetailsButton: false,
        ),
      ),
    ),
  );

  expect(find.text('Mostrar detalhes'), findsNothing);
});
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/home/widgets/trip_request_card_test.dart`
Expected: the new compact-mode test fails until the widget accepts a show-details flag.

- [ ] **Step 3: Implement the widget flag**

```dart
class TripRequestCard extends StatefulWidget {
  final bool showDetailsButton;

  const TripRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.onShowDetails,
    this.onPriceFieldFocusChanged,
    this.reduceEffects = false,
    this.showDetailsButton = true,
  });
}

if (widget.showDetailsButton) ...[
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: widget.onShowDetails,
      icon: const Icon(Icons.visibility_rounded, size: 18),
      label: const Text('Mostrar detalhes'),
    ),
  ),
]
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/home/widgets/trip_request_card_test.dart`
Expected: both the existing and compact-mode card tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/trip_request_card.dart test/features/home/widgets/trip_request_card_test.dart
git commit -m "feat(widget): torna card de solicitação configurável"
```

### Task 3: Increase the active-trip navigation zoom preset

**Files:**
- Modify: `lib/features/trip/presentation/pages/active_trip_page.dart`
- Modify: `test/features/trip/domain/navigation_camera_state_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('navigation zoom preset is closer for pickup and trip phases', () {
  const zoom = 19.6;
  expect(zoom, greaterThan(18.5));
});
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/trip/domain/navigation_camera_state_test.dart`
Expected: the new zoom expectation fails until the constant is updated.

- [ ] **Step 3: Update the preset**

```dart
const double _navigationTiltZoom = 19.6;
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/trip/domain/navigation_camera_state_test.dart`
Expected: navigation zoom test passes, and the active trip page uses the tighter zoom for pickup and in-trip movement.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trip/presentation/pages/active_trip_page.dart test/features/trip/domain/navigation_camera_state_test.dart
git commit -m "feat(navigation): aproxima zoom da câmera no GPS da corrida"
```

### Task 4: Verify the end-to-end widget behavior

**Files:**
- Test: `test/features/home/widgets/trip_request_card_test.dart`
- Test: `test/features/trip/domain/navigation_camera_state_test.dart`

- [ ] **Step 1: Run the focused tests**

Run: `flutter test test/features/home/widgets/trip_request_card_test.dart test/features/trip/domain/navigation_camera_state_test.dart`

- [ ] **Step 2: Confirm the expected outputs**

Expected: all widget and domain tests pass with the request-surface split and tighter navigation zoom in place.

- [ ] **Step 3: Commit verification state**

```bash
git add test/features/home/widgets/trip_request_card_test.dart test/features/trip/domain/navigation_camera_state_test.dart
git commit -m "test: cobre solicitação em tela cheia e zoom GPS mais fechado"
```
