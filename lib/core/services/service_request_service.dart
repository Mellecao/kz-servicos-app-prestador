import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kz_servicos_prestador/core/models/service_request_data.dart';

const _serviceRequestSelect =
    '*, service_categories(name), addresses(formatted_address), '
    'client:users!client_id(full_name), service_request_photos(*)';

class ServiceRequestService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Set<String>> getProviderCategoryIds(String providerProfileId) async {
    try {
      final categoriesRes = await _client
          .from('provider_category_services')
          .select('service_category_id')
          .eq('provider_profile_id', providerProfileId);

      return (categoriesRes as List)
          .map((c) => (c as Map)['service_category_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();
    } catch (e) {
      debugPrint('[ServiceRequestService] getProviderCategoryIds erro: $e');
      return {};
    }
  }

  /// Solicitações disponíveis para o prestador (das suas categorias) +
  /// solicitações que ele já aceitou.
  Future<List<ServiceRequestData>> getProviderRequests(
    String providerProfileId,
  ) async {
    try {
      final categoryIds = await getProviderCategoryIds(providerProfileId);

      final requests = <ServiceRequestData>[];

      if (categoryIds.isNotEmpty) {
        final openRes = await _client
            .from('service_requests')
            .select(_serviceRequestSelect)
            .filter('provider_profile_id', 'is', null)
            .eq('status', 'open')
            .inFilter('service_category_id', categoryIds.toList())
            .order('service_date');

        requests.addAll(
          (openRes as List)
              .map((m) => ServiceRequestData.fromMap(m as Map<String, dynamic>)),
        );
      }

      final acceptedRes = await _client
          .from('service_requests')
          .select(_serviceRequestSelect)
          .eq('provider_profile_id', providerProfileId)
          .order('service_date');

      requests.addAll(
        (acceptedRes as List)
            .map((m) => ServiceRequestData.fromMap(m as Map<String, dynamic>)),
      );

      // Subprojeto 6: requests com freeform_profession (sem categoria fixa)
      // para as quais o prestador foi CONVIDADO pelo admin via
      // service_request_provider_candidates (status='pending').
      try {
        final invitedRes = await _client
            .from('service_request_provider_candidates')
            .select(
              'service_request_id, status, '
              'service_requests!inner(*, service_categories(name), '
              'addresses(formatted_address), '
              'client:users!client_id(full_name), '
              'service_request_photos(*))',
            )
            .eq('provider_profile_id', providerProfileId)
            .eq('status', 'pending');

        for (final row in invitedRes as List) {
          final map = (row as Map<String, dynamic>)['service_requests'];
          if (map is Map<String, dynamic>) {
            requests.add(ServiceRequestData.fromMap(map));
          }
        }
      } catch (e) {
        debugPrint('[ServiceRequestService] invited fetch erro: $e');
      }

      return requests;
    } catch (e) {
      debugPrint('[ServiceRequestService] getProviderRequests erro: $e');
      return [];
    }
  }

  /// Aceita uma solicitação (status open → assigned).
  Future<bool> acceptRequest(
    String requestId,
    String providerProfileId,
  ) async {
    try {
      await _client.from('service_requests').update({
        'provider_profile_id': providerProfileId,
        'status': 'assigned',
      }).eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('[ServiceRequestService] acceptRequest erro: $e');
      return false;
    }
  }
}
