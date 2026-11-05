import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kz_servicos_prestador/core/models/service_request_data.dart';
import 'package:kz_servicos_prestador/features/other_services/domain/service_request_flow.dart';

const _serviceRequestSelect =
    '*, service_categories(name), addresses(formatted_address), '
    'client:users!client_id(full_name), service_request_photos(*)';

/// Fluxo de serviços do prestador (ver `service_request_flow.dart`).
///
/// Convites chegam do administrador em `service_request_provider_candidates`;
/// o prestador propõe preço ou recusa; o administrador escolhe
/// (`select_service_request_provider`); depois o prestador confirma, inicia e
/// conclui. Pedidos `open` não são visíveis ao prestador (RLS).
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

  /// Convites (pending/accepted) do prestador + pedidos que já lhe pertencem.
  /// Lança se a consulta principal falhar (a página mostra o erro).
  Future<List<ServiceRequestData>> getProviderRequests(
    String providerProfileId,
  ) async {
    final mineRes = await _client
        .from('service_requests')
        .select(_serviceRequestSelect)
        .eq('provider_profile_id', providerProfileId)
        .order('service_date');

    final byId = <String, ServiceRequestData>{
      for (final m in (mineRes as List).cast<Map<String, dynamic>>())
        m['id'] as String: ServiceRequestData.fromMap(m),
    };

    try {
      final invitedRes = await _client
          .from('service_request_provider_candidates')
          .select(
            'service_request_id, status, offered_price, '
            'service_requests!inner($_serviceRequestSelect)',
          )
          .eq('provider_profile_id', providerProfileId)
          .inFilter('status', ['pending', 'accepted']);

      for (final row in (invitedRes as List).cast<Map<String, dynamic>>()) {
        final invited = ServiceRequestData.fromInviteRow(row);
        if (invited == null) continue;
        // Se o pedido já é meu, prevalece a versão "meu" (estado real).
        byId.putIfAbsent(invited.id, () => invited);
      }
    } catch (e) {
      debugPrint('[ServiceRequestService] convites erro: $e');
    }

    final list = byId.values.toList()
      ..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
    return list;
  }

  /// Propõe preço a um convite: `offered_price` + `accepted` + `responded_at`.
  Future<void> proposePrice({
    required String requestId,
    required String providerProfileId,
    required double price,
  }) async {
    final rows = await _updateCandidate(
      requestId: requestId,
      providerProfileId: providerProfileId,
      values: {
        'offered_price': price,
        'status': 'accepted',
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    ensureRowsAffected(rows, 'Não foi possível enviar a proposta.');
  }

  /// Recusa um convite (`rejected` + `responded_at`).
  Future<void> declineInvite({
    required String requestId,
    required String providerProfileId,
  }) async {
    final rows = await _updateCandidate(
      requestId: requestId,
      providerProfileId: providerProfileId,
      values: {
        'status': 'rejected',
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    ensureRowsAffected(rows, 'Não foi possível recusar o convite.');
  }

  /// Confirmar / iniciar / concluir um pedido que já é do prestador.
  Future<void> advance({
    required String requestId,
    required String providerProfileId,
    required ProviderServiceAction action,
  }) async {
    final next = nextStatusFor(action);
    if (next == null) {
      throw const ServiceActionException('Ação inválida para este pedido.');
    }
    final rows = await _client
        .from('service_requests')
        .update({'status': next})
        .eq('id', requestId)
        .eq('provider_profile_id', providerProfileId)
        .select('id, status');
    ensureRowsAffected(rows, 'Não foi possível atualizar o serviço.');
  }

  Future<List<dynamic>> _updateCandidate({
    required String requestId,
    required String providerProfileId,
    required Map<String, dynamic> values,
  }) {
    return _client
        .from('service_request_provider_candidates')
        .update(values)
        .eq('service_request_id', requestId)
        .eq('provider_profile_id', providerProfileId)
        .eq('status', 'pending')
        .select('id');
  }
}
