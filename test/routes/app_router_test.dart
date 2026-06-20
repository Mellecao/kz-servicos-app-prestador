import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/routes/app_router.dart';

void main() {
  group('AppRouter.activeTripHomeRedirect', () {
    test('redirects home with active trip marker back to active trip', () {
      final redirect = AppRouter.activeTripHomeRedirect(
        Uri.parse('/home?returnToActiveTripId=trip-123'),
      );

      expect(redirect, '/active-trip?tripId=trip-123');
    });

    test('does not redirect ordinary home navigation', () {
      final redirect = AppRouter.activeTripHomeRedirect(Uri.parse('/home'));

      expect(redirect, isNull);
    });

    test('does not redirect other active-trip-aware tabs', () {
      final redirect = AppRouter.activeTripHomeRedirect(
        Uri.parse('/schedules?returnToActiveTripId=trip-123'),
      );

      expect(redirect, isNull);
    });
  });
}
