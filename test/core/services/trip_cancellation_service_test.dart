import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/services/trip_cancellation_service.dart';

void main() {
  test('monta payload pendente com motivo normalizado', () {
    expect(
      TripCancellationService.buildRequestPayload(
        tripId: 'trip-123',
        requestedBy: 'driver-456',
        reason: '  Problema mecanico no veiculo  ',
      ),
      {
        'trip_id': 'trip-123',
        'requested_by': 'driver-456',
        'reason': 'Problema mecanico no veiculo',
        'status': 'pending',
      },
    );
  });

  test('converte resposta do banco em pedido de cancelamento', () {
    final request = TripCancellationRequestData.fromMap({
      'id': 'request-1',
      'trip_id': 'trip-123',
      'requested_by': 'driver-456',
      'reason': 'Problema mecanico no veiculo',
      'status': 'rejected',
      'review_reason': 'Outro motorista sera enviado',
      'created_at': '2026-07-14T12:00:00Z',
    });

    expect(request.isPending, isFalse);
    expect(request.reviewReason, 'Outro motorista sera enviado');
    expect(request.createdAt.isUtc, isTrue);
  });
}
