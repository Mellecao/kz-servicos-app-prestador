import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';

TripData makeTrip({
  required String status,
  String? candidateStatus,
  String? clientId,
  String tripType = 'standard',
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
    tripType: tripType,
  );
}

void main() {
  group('TripData.statusLabel', () {
    test(
      'searching_drivers com candidateStatus=accepted mostra "A aguardar aprovação da Só Serviços"',
      () {
        final trip = makeTrip(
          status: 'searching_drivers',
          candidateStatus: 'accepted',
        );
        expect(trip.statusLabel, 'A aguardar aprovação da Só Serviços');
      },
    );

    test(
      'searching_drivers sem candidateStatus mantém "À procura de motoristas"',
      () {
        final trip = makeTrip(status: 'searching_drivers');
        expect(trip.statusLabel, 'À procura de motoristas');
      },
    );

    test(
      'awaiting_client_confirmation mostra "A aguardar que o passageiro aceite"',
      () {
        final trip = makeTrip(status: 'awaiting_client_confirmation');
        expect(trip.statusLabel, 'A aguardar que o passageiro aceite');
      },
    );

    test('awaiting_driver_confirmation mostra re-check do motorista', () {
      final trip = makeTrip(status: 'awaiting_driver_confirmation');
      expect(trip.statusLabel, 'A aguardar re-check do motorista');
    });

    test(
      'pedido direto awaiting_driver_confirmation aguarda proposta do motorista',
      () {
        final trip = makeTrip(
          status: 'awaiting_driver_confirmation',
          candidateStatus: 'pending',
          tripType: 'scheduled_choose_driver',
        );

        expect(trip.statusLabel, 'A aguardar proposta do motorista');
      },
    );

    test('pedido direto aceito vira re-check do motorista', () {
      final trip = makeTrip(
        status: 'awaiting_driver_confirmation',
        candidateStatus: 'accepted',
        tripType: 'scheduled_choose_driver',
      );

      expect(trip.isScheduledDirectRequest, isFalse);
      expect(trip.isDriverRecheck, isTrue);
      expect(trip.statusLabel, 'A aguardar re-check do motorista');
    });

    test('scheduled mostra "Agendada"', () {
      final trip = makeTrip(status: 'scheduled');
      expect(trip.statusLabel, 'Agendada');
    });
  });

  group('TripData.isAwaitingKzApproval', () {
    test('true quando searching_drivers + candidateStatus=accepted', () {
      final trip = makeTrip(
        status: 'searching_drivers',
        candidateStatus: 'accepted',
      );
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

  group('TripData.copyWith', () {
    test('atualiza status mantendo demais campos', () {
      final original = makeTrip(status: 'searching_drivers');

      final updated = original.copyWith(
        status: 'awaiting_driver_confirmation',
        candidateStatus: 'accepted',
      );

      expect(updated.status, 'awaiting_driver_confirmation');
      expect(updated.candidateStatus, 'accepted');
      expect(updated.tripId, original.tripId);
      expect(updated.clientName, original.clientName);
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
      final noCandStatus = Map<String, dynamic>.from(map)
        ..remove('candidate_status');
      final trip = TripData.fromMap(noCandStatus);
      expect(trip.candidateStatus, isNull);
    });

    test('tripType default é standard quando ausente', () {
      final trip = TripData.fromMap(map);
      expect(trip.tripType, 'standard');
      expect(trip.isFlash, isFalse);
    });

    test('parseia trip_type=flash', () {
      final flashMap = Map<String, dynamic>.from(map)..['trip_type'] = 'flash';
      final trip = TripData.fromMap(flashMap);
      expect(trip.tripType, 'flash');
      expect(trip.isFlash, isTrue);
    });

    test(
      'extrai candidate_status de trip_driver_candidates embutido quando a chave plana está ausente',
      () {
        final embeddedMap = Map<String, dynamic>.from(map)
          ..remove('candidate_status')
          ..['trip_driver_candidates'] = [
            {'status': 'accepted'},
          ];
        final trip = TripData.fromMap(embeddedMap);
        expect(trip.candidateStatus, 'accepted');
      },
    );

    test(
      'chave plana candidate_status tem prioridade sobre trip_driver_candidates embutido',
      () {
        final embeddedMap = Map<String, dynamic>.from(map)
          ..['candidate_status'] = 'pending'
          ..['trip_driver_candidates'] = [
            {'status': 'accepted'},
          ];
        final trip = TripData.fromMap(embeddedMap);
        expect(trip.candidateStatus, 'pending');
      },
    );

    test(
      'reproduz bug do re-check: trip vinda de getDriverScheduledTrips/getDriverRecheckRequests '
      'com candidatura já aceita deve ser reconhecida como recheck, não como pedido direto novo',
      () {
        final recheckMap = Map<String, dynamic>.from(map)
          ..remove('candidate_status')
          ..['status'] = 'awaiting_driver_confirmation'
          ..['trip_type'] = 'scheduled_choose_driver'
          ..['trip_driver_candidates'] = [
            {'status': 'accepted'},
          ];
        final trip = TripData.fromMap(recheckMap);
        expect(trip.isScheduledDirectRequest, isFalse);
        expect(trip.isDriverRecheck, isTrue);
      },
    );

    test('parseia e ordena passageiros nomeados com alertas infantis', () {
      final relationMap = Map<String, dynamic>.from(map)
        ..['trip_passengers'] = [
          {
            'name': 'Carlos',
            'age': 34,
            'needs_car_seat': false,
            'sort_order': 2,
          },
          {'name': 'Lia', 'age': 5, 'needs_car_seat': true, 'sort_order': 1},
        ];

      final trip = TripData.fromMap(relationMap);

      expect(trip.passengers.map((p) => p.name), ['Lia', 'Carlos']);
      expect(trip.passengerLabels, ['Carlos — 34 anos']);
      expect(trip.childLabels, ['Lia — 5 anos (levar cadeirinha)']);
      expect(trip.regularPassengerCount, 1);
      expect(trip.displayChildrenCount, 1);
    });

    test('parseia e ordena detalhes completos de bagagem', () {
      final relationMap = Map<String, dynamic>.from(map)
        ..['trip_luggage'] = [
          {
            'type': 'carry_on',
            'size': 'small',
            'weight_kg': 8,
            'quantity': 1,
            'sort_order': 2,
          },
          {
            'type': 'suitcase',
            'size': 'large',
            'weight_kg': 23.5,
            'quantity': 2,
            'sort_order': 1,
          },
        ];

      final trip = TripData.fromMap(relationMap);

      expect(trip.luggage.map((item) => item.type), ['suitcase', 'carry_on']);
      expect(trip.luggageLabels, [
        '2x Mala grande (23,5 kg cada)',
        '1x Bagagem de mão pequena (8 kg)',
      ]);
    });
  });
}
