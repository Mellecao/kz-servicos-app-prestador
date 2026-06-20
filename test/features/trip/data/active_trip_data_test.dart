import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';

void main() {
  group('ActiveTripData.fromMap', () {
    test('parseia dados de viagem ativa com joins atuais', () {
      final trip = ActiveTripData.fromMap({
        'id': 'trip-1',
        'client_id': 'client-1',
        'status': 'started',
        'driver_arrived_at': '2026-05-26T10:00:00.000Z',
        'started_at': null,
        'finished_at': null,
        'is_driver_paied': false,
        'payment_method': 'pix',
        'scheduled_datetime': '2026-05-26T09:30:00.000Z',
        'passenger_count': 2,
        'pickup_address': {
          'formatted_address': 'Av. Paulista, 1000',
          'latitude': -23.561,
          'longitude': -46.656,
        },
        'dropoff_address': {
          'formatted_address': 'Aeroporto Congonhas',
          'latitude': -23.627,
          'longitude': -46.656,
        },
        'client': {
          'full_name': 'Maria',
          'phone': '11999999999',
          'avatar_url': 'https://example.com/maria.jpg',
        },
        'trip_driver_candidates': [
          {'id': 'cand-1', 'offered_price': 42.5, 'status': 'accepted'},
        ],
      });

      expect(trip.id, 'trip-1');
      expect(trip.candidateId, 'cand-1');
      expect(trip.clientName, 'Maria');
      expect(trip.clientAvatarUrl, 'https://example.com/maria.jpg');
      expect(trip.pickupAddress, 'Av. Paulista, 1000');
      expect(trip.destinationAddress, 'Aeroporto Congonhas');
      expect(trip.offeredPrice, 42.5);
      expect(trip.paymentMethodLabel, 'PIX');
      expect(trip.driverArrivedAt, isNotNull);
      expect(trip.startedAt, isNull);
    });

    test('usa final_price quando nao existe oferta de candidato', () {
      final trip = ActiveTripData.fromMap({
        'id': 'trip-2',
        'status': 'finished',
        'final_price': 75,
        'is_driver_paied': true,
        'pickup_address': {'latitude': -23.5, 'longitude': -46.6},
        'dropoff_address': {'latitude': -23.6, 'longitude': -46.7},
      });

      expect(trip.offeredPrice, 75);
      expect(trip.status, 'finished');
      expect(trip.isDriverPaid, isTrue);
    });
  });
}
