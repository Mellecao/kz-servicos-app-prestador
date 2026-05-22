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

  group('TripData.fromMap()', () {
    final map = {
      'id': 'trip-1',
      'candidate_id': 'cand-1',
      'client_id': 'user-xyz',
      'candidate_status': 'accepted',
      'client': {'full_name': 'João', 'phone': null},
      'pickup_address': {
        'formatted_address': 'Av. Paulista, 1000',
        'latitude': -23.5505,
        'longitude': -46.6333,
      },
      'dropoff_address': {
        'formatted_address': 'Aeroporto Congonhas',
        'latitude': -23.6273,
        'longitude': -46.6566,
      },
      'scheduled_datetime': '2026-05-25T14:30:00.000',
      'passenger_count': 2,
      'children_count': 0,
      'luggage_count': 1,
      'status': 'searching_drivers',
    };

    test('parseia client_id corretamente', () {
      final trip = TripData.fromMap(map);
      expect(trip.clientId, 'user-xyz');
    });

    test('parseia candidate_status corretamente', () {
      final trip = TripData.fromMap(map);
      expect(trip.candidateStatus, 'accepted');
    });

    test('clientId é null quando ausente no map', () {
      final noClientId = Map<String, dynamic>.from(map)..remove('client_id');
      final trip = TripData.fromMap(noClientId);
      expect(trip.clientId, isNull);
    });

    test('candidateStatus é null quando ausente no map', () {
      final noCandStatus = Map<String, dynamic>.from(map)..remove('candidate_status');
      final trip = TripData.fromMap(noCandStatus);
      expect(trip.candidateStatus, isNull);
    });
  });
}
