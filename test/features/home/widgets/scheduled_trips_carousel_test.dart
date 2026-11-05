import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/scheduled_trips_carousel.dart';

TripData makeTrip(String id, String status, {String? candidateStatus}) =>
    TripData(
      tripId: id,
      candidateId: '',
      clientName: 'João Silva',
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
      paymentMethod: 'pix',
    );

Widget buildCarousel(List<TripData> trips, {void Function(TripData)? onTap}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          ScheduledTripsCarousel(trips: trips, onTap: onTap ?? (_) {}),
        ],
      ),
    ),
  );
}

void main() {
  group('ScheduledTripsCarousel', () {
    testWidgets('exibe nome do cliente', (tester) async {
      await tester.pumpWidget(buildCarousel([makeTrip('1', 'scheduled')]));
      expect(find.text('João Silva'), findsOneWidget);
    });

    testWidgets(
      'exibe badge "A aguardar aprovação da Só Serviços" quando candidateStatus=accepted',
      (tester) async {
        await tester.pumpWidget(
          buildCarousel([
            makeTrip('1', 'searching_drivers', candidateStatus: 'accepted'),
          ]),
        );
        expect(
          find.text('A aguardar aprovação da Só Serviços'),
          findsOneWidget,
        );
      },
    );

    testWidgets('exibe badge de re-check quando passageiro aprovou', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCarousel([makeTrip('1', 'awaiting_driver_confirmation')]),
      );
      expect(find.text('A aguardar re-check do motorista'), findsOneWidget);
    });

    testWidgets('exibe dots de paginação quando há mais de uma corrida', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCarousel([makeTrip('1', 'scheduled'), makeTrip('2', 'scheduled')]),
      );
      expect(
        find.byKey(const ValueKey('scheduled_trip_dot_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('scheduled_trip_dot_1')),
        findsOneWidget,
      );
    });

    testWidgets('não exibe dots quando há apenas uma corrida', (tester) async {
      await tester.pumpWidget(buildCarousel([makeTrip('1', 'scheduled')]));
      expect(find.byKey(const ValueKey('scheduled_trip_dot_0')), findsNothing);
    });

    testWidgets('chama onTap ao tocar no card', (tester) async {
      TripData? tapped;
      final trip = makeTrip('1', 'scheduled');
      await tester.pumpWidget(buildCarousel([trip], onTap: (t) => tapped = t));
      await tester.tap(find.text('João Silva'));
      expect(tapped?.tripId, '1');
    });
  });
}
