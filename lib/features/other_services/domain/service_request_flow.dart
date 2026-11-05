import 'package:kz_servicos_prestador/core/models/service_request_data.dart';
import 'package:kz_servicos_prestador/core/utils/kz_format.dart';

/// Preço a mostrar no cartão: "Preço por propor" enquanto não há valor.
String servicePriceLabel(ServiceRequestData request) => request.displayPrice > 0
    ? formatKz(request.displayPrice)
    : 'Preço por propor';

/// Linhas da descrição no cartão. Num convite por responder o texto do cliente
/// é a única informação para fixar o preço, por isso mostra-se completo
/// (`null` = sem limite); nos restantes estados o cartão resume em 2 linhas.
int? requestDescriptionMaxLines(ProviderServiceAction action) =>
    action == ProviderServiceAction.proposePrice ? null : 2;

/// Ação disponível ao prestador sobre um pedido de serviço.
///
/// Fluxo canónico: convite (pending) → propõe preço → o administrador escolhe
/// (`select_service_request_provider`) → o prestador confirma → inicia →
/// conclui.
enum ProviderServiceAction {
  proposePrice,
  awaitingAdmin,
  awaitingClient,
  confirm,
  start,
  finish,
  none,
}

ProviderServiceAction providerActionFor(
  ServiceRequestData request,
  String providerProfileId,
) {
  final assignedTo = request.providerProfileId;

  if (assignedTo == null) {
    return switch (request.candidateStatus) {
      'pending' => ProviderServiceAction.proposePrice,
      'accepted' => ProviderServiceAction.awaitingAdmin,
      _ => ProviderServiceAction.none,
    };
  }
  if (assignedTo != providerProfileId) return ProviderServiceAction.none;

  return switch (request.status) {
    'awaiting_client_confirmation' => ProviderServiceAction.awaitingClient,
    'awaiting_provider_confirmation' => ProviderServiceAction.confirm,
    'assigned' => ProviderServiceAction.start,
    'in_progress' => ProviderServiceAction.finish,
    _ => ProviderServiceAction.none,
  };
}

/// Estado de `service_requests` que a ação grava (só as transições do
/// prestador). `null` para as ações que não mudam o pedido.
String? nextStatusFor(ProviderServiceAction action) => switch (action) {
  ProviderServiceAction.confirm => 'assigned',
  ProviderServiceAction.start => 'in_progress',
  ProviderServiceAction.finish => 'finished',
  _ => null,
};

String serviceStatusLabel(
  ServiceRequestData request,
  String providerProfileId,
) {
  if (request.providerProfileId == null) {
    return switch (request.candidateStatus) {
      'pending' => 'Convite — proponha o seu preço',
      'accepted' => 'Proposta enviada · a aguardar o administrador',
      'rejected' => 'Convite recusado',
      _ => 'Pedido',
    };
  }
  return switch (request.status) {
    'awaiting_client_confirmation' => 'A aguardar a confirmação do cliente',
    'awaiting_provider_confirmation' => 'Aguarda a sua confirmação',
    'assigned' => 'Confirmado',
    'in_progress' => 'Em curso',
    'finished' => 'Concluído',
    'cancelled' => 'Cancelado',
    _ => 'Pedido',
  };
}

const double _maxKzAmount = 1e9;

/// Lê um valor em Kwanza escrito pelo utilizador (`15000`, `15.000`,
/// `15.000,50`, `1.500,00 Kz`). `null` se for inválido ou não positivo.
double? parseKzAmount(String input) {
  var text = input.replaceAll(RegExp(r'kz', caseSensitive: false), '').trim();
  text = text.replaceAll(RegExp(r'\s'), '');
  if (text.isEmpty) return null;

  final commas = ','.allMatches(text).length;
  if (commas > 1) return null;

  String normalized;
  if (commas == 1) {
    // `.` é separador de milhar, `,` é o decimal.
    normalized = text.replaceAll('.', '').replaceFirst(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(text)) {
    normalized = text.replaceAll('.', '');
  } else {
    normalized = text;
  }

  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) return null;
  final value = double.tryParse(normalized);
  if (value == null || value <= 0 || value >= _maxKzAmount) return null;
  return value;
}

class ServiceActionException implements Exception {
  final String message;
  const ServiceActionException(this.message);

  @override
  String toString() => message;
}

/// O Supabase não devolve erro quando a RLS filtra o UPDATE (0 linhas).
/// Chame com o resultado de `.update(...).select()`.
void ensureRowsAffected(List<dynamic>? rows, String message) {
  if (rows == null || rows.isEmpty) throw ServiceActionException(message);
}
