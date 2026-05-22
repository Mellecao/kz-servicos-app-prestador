import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/scheduled_trips_service.dart';

TripData makeTrip(String id, DateTime scheduledAt) => TripData(
      tripId: id,
      candidateId: '',
      clientName: 'Cliente',
      origin: 'A',
      destination: 'B',
      originLat: 0, originLng: 0, destinationLat: 0, destinationLng: 0,
      scheduledAt: scheduledAt,
      passengerCount: 1,
      childrenCount: 0,
      luggageCount: 0,
      status: 'scheduled',
    );

void main() {
  group('ScheduledTripsService.mergeAndSort', () {
    test('deduplica por tripId mantendo primeira ocorrência', () {
      final t1 = makeTrip('a', DateTime(2026, 5, 26));
      final t2 = makeTrip('b', DateTime(2026, 5, 25));
      final t3 = makeTrip('a', DateTime(2026, 5, 26)); // duplicado

      final result = ScheduledTripsService.mergeAndSort([t1, t3], [t2]);

      expect(result.length, 2);
    });

    test('ordena por scheduledAt crescente', () {
      final t1 = makeTrip('a', DateTime(2026, 5, 26));
      final t2 = makeTrip('b', DateTime(2026, 5, 24));
      final t3 = makeTrip('c', DateTime(2026, 5, 25));

      final result = ScheduledTripsService.mergeAndSort([t1], [t2, t3]);

      expect(result.map((t) => t.tripId).toList(), ['b', 'c', 'a']);
    });

    test('retorna lista vazia quando ambas as listas são vazias', () {
      final result = ScheduledTripsService.mergeAndSort([], []);
      expect(result, isEmpty);
    });
  });
}
