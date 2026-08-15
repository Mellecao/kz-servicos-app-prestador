import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/other_services/domain/service_request_realtime_reload_policy.dart';

void main() {
  group('ServiceRequestRealtimeReloadPolicy', () {
    test('reloads open requests in provider categories', () {
      final shouldReload = ServiceRequestRealtimeReloadPolicy.changeTargetsProvider(
        providerProfileId: 'provider-1',
        providerCategoryIds: {'category-1'},
        newRecord: {
          'provider_profile_id': null,
          'service_category_id': 'category-1',
          'status': 'open',
        },
      );

      expect(shouldReload, isTrue);
    });

    test('reloads requests assigned to provider', () {
      final shouldReload = ServiceRequestRealtimeReloadPolicy.changeTargetsProvider(
        providerProfileId: 'provider-1',
        providerCategoryIds: {'category-1'},
        newRecord: {
          'provider_profile_id': 'provider-1',
          'service_category_id': 'category-2',
          'status': 'assigned',
        },
      );

      expect(shouldReload, isTrue);
    });

    test('reloads requests previously assigned to provider', () {
      final shouldReload = ServiceRequestRealtimeReloadPolicy.changeTargetsProvider(
        providerProfileId: 'provider-1',
        providerCategoryIds: {'category-1'},
        oldRecord: {'provider_profile_id': 'provider-1'},
        newRecord: {
          'provider_profile_id': null,
          'service_category_id': 'category-2',
          'status': 'open',
        },
      );

      expect(shouldReload, isTrue);
    });

    test('ignores unrelated category and provider changes', () {
      final shouldReload = ServiceRequestRealtimeReloadPolicy.changeTargetsProvider(
        providerProfileId: 'provider-1',
        providerCategoryIds: {'category-1'},
        newRecord: {
          'provider_profile_id': null,
          'service_category_id': 'category-2',
          'status': 'open',
        },
      );

      expect(shouldReload, isFalse);
    });
  });
}
