import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/home/domain/home_realtime_reload_policy.dart';

void main() {
  group('HomeRealtimeReloadPolicy', () {
    test('reloads candidate changes for the current driver', () {
      final shouldReload = HomeRealtimeReloadPolicy.candidateChangeTargetsDriver(
        driverProfileId: 'driver-1',
        newRecord: {'driver_profile_id': 'driver-1'},
      );

      expect(shouldReload, isTrue);
    });

    test('ignores candidate changes for another driver', () {
      final shouldReload = HomeRealtimeReloadPolicy.candidateChangeTargetsDriver(
        driverProfileId: 'driver-1',
        newRecord: {'driver_profile_id': 'driver-2'},
      );

      expect(shouldReload, isFalse);
    });

    test('reloads trip changes assigned to the current driver', () {
      final shouldReload = HomeRealtimeReloadPolicy.tripChangeTargetsDriver(
        driverProfileId: 'driver-1',
        newRecord: {
          'driver_profile_id': 'driver-1',
          'status': 'awaiting_driver_confirmation',
        },
      );

      expect(shouldReload, isTrue);
    });

    test('reloads trip changes that were assigned to the current driver before update', () {
      final shouldReload = HomeRealtimeReloadPolicy.tripChangeTargetsDriver(
        driverProfileId: 'driver-1',
        oldRecord: {'driver_profile_id': 'driver-1'},
        newRecord: {'driver_profile_id': null, 'status': 'searching_drivers'},
      );

      expect(shouldReload, isTrue);
    });

    test('ignores unrelated trip changes', () {
      final shouldReload = HomeRealtimeReloadPolicy.tripChangeTargetsDriver(
        driverProfileId: 'driver-1',
        newRecord: {
          'driver_profile_id': 'driver-2',
          'status': 'awaiting_driver_confirmation',
        },
      );

      expect(shouldReload, isFalse);
    });
  });
}
