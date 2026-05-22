import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';

TripData makeTrip({
  required String status,
  String? candidateStatus,
  String? clientId,
}) {
  return TripData(
    tripId: 'trip-1',
    candidateId: 'cand-1',
    clientName: 'João',
    origin: 'Av. Paulista, 1000',
    destination: 'Aeroporto Congonhas',
    originLat: -23.5505,
    originLng: -46.6333,
    destinationLat: -23.6273,
    destinationLng: -46.6566,
    scheduledAt: DateTime(2026, 5, 25, 14, 30),
    passengerCount: 2,
    childrenCount: 0,
    luggageCount: 1,
    status: status,
    candidateStatus: candidateStatus,
    clientId: clientId,
  );
}

void main() {
  group('TripData.statusLabel', () {
    test('searching_drivers com candidateStatus=accepted mostra "Aguardando aprovação da KZ"', () {
      final trip = makeTrip(status: 'searching_drivers', candidateStatus: 'accepted');
      expect(trip.statusLabel, 'Aguardando aprovação da KZ');
    });

    test('searching_drivers sem candidateStatus mantém "Buscando motoristas"', () {
      final trip = makeTrip(status: 'searching_drivers');
      expect(trip.statusLabel, 'Buscando motoristas');
    });

    test('awaiting_client_confirmation mostra "Aguardando passageiro aceitar"', () {
      final trip = makeTrip(status: 'awaiting_client_confirmation');
      expect(trip.statusLabel, 'Aguardando passageiro aceitar');
    });

    test('scheduled mostra "Agendada"', () {
      final trip = makeTrip(status: 'scheduled');
      expect(trip.statusLabel, 'Agendada');
    });
  });

  group('TripData.isAwaitingKzApproval', () {
    test('true quando searching_drivers + candidateStatus=accepted', () {
      final trip = makeTrip(status: 'searching_drivers', candidateStatus: 'accepted');
      expect(trip.isAwaitingKzApproval, isTrue);
    });

    test('false quando searching_drivers sem candidateStatus', () {
      final trip = makeTrip(status: 'searching_drivers');
      expect(trip.isAwaitingKzApproval, isFalse);
    });

    test('false quando scheduled mesmo com candidateStatus', () {
      final trip = makeTrip(status: 'scheduled', candidateStatus: 'accepted');
      expect(trip.isAwaitingKzApproval, isFalse);
    });
  });

  group('TripData.clientId', () {
    test('retorna clientId quando fornecido', () {
      final trip = makeTrip(status: 'scheduled', clientId: 'user-abc');
      expect(trip.clientId, 'user-abc');
    });

    test('retorna null quando não fornecido', () {
      final trip = makeTrip(status: 'scheduled');
      expect(trip.clientId, isNull);
    });
  });
}
