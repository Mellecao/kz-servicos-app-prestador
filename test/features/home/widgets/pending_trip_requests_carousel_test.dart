import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/pending_trip_requests_carousel.dart';

TripData makePendingTrip(
  String id, {
  String status = 'searching_drivers',
  String? candidateStatus,
  String tripType = 'standard',
  List<TripPassenger> passengers = const [],
}) => TripData(
  tripId: id,
  candidateId: 'candidate-$id',
  clientName: 'Cliente $id',
  origin: 'Origem $id',
  destination: 'Destino $id',
  originLat: -23.5505,
  originLng: -46.6333,
  destinationLat: -23.6273,
  destinationLng: -46.6566,
  scheduledAt: DateTime(2026, 7, 2, 14, 30),
  passengerCount: 2,
  childrenCount: 0,
  luggageCount: 1,
  status: status,
  candidateStatus: candidateStatus,
  tripType: tripType,
  offeredPrice: 75,
  paymentMethod: 'pix',
  passengers: passengers,
);

Widget buildCarousel(
  List<TripData> trips, {
  required String selectedTripId,
  void Function(TripData)? onTap,
  void Function(TripData)? onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PendingTripRequestsCarousel(
        trips: trips,
        selectedTripId: selectedTripId,
        onTripTap: onTap ?? (_) {},
        onTripChanged: onChanged ?? (_) {},
      ),
    ),
  );
}

void main() {
  group('PendingTripRequestsCarousel', () {
    testWidgets('exibe cliente e contador de solicitações', (tester) async {
      await tester.pumpWidget(
        buildCarousel([
          makePendingTrip('1'),
          makePendingTrip('2'),
        ], selectedTripId: '1'),
      );

      expect(find.text('Solicitações pendentes (2)'), findsOneWidget);
      expect(find.text('Cliente 1'), findsOneWidget);
    });

    testWidgets('destaca corrida aguardando confirmação do motorista', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCarousel([
          makePendingTrip('1', status: 'awaiting_driver_confirmation'),
          makePendingTrip('2'),
        ], selectedTripId: '1'),
      );

      expect(find.text('Confirmação pendente'), findsOneWidget);
    });

    testWidgets('pedido direto pendente aparece como nova solicitação', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCarousel([
          makePendingTrip(
            '1',
            status: 'awaiting_driver_confirmation',
            candidateStatus: 'pending',
            tripType: 'scheduled_choose_driver',
          ),
        ], selectedTripId: '1'),
      );

      expect(find.text('Nova solicitação'), findsOneWidget);
      expect(find.text('Confirmação pendente'), findsNothing);
    });

    testWidgets('dispara callback ao tocar no card atual', (tester) async {
      TripData? tapped;

      await tester.pumpWidget(
        buildCarousel(
          [makePendingTrip('1'), makePendingTrip('2')],
          selectedTripId: '1',
          onTap: (trip) => tapped = trip,
        ),
      );

      await tester.tap(find.text('Cliente 1'));

      expect(tapped?.tripId, '1');
    });

    testWidgets('dispara callback ao deslizar para outra corrida', (
      tester,
    ) async {
      TripData? changed;

      await tester.pumpWidget(
        buildCarousel(
          [makePendingTrip('1'), makePendingTrip('2')],
          selectedTripId: '1',
          onChanged: (trip) => changed = trip,
        ),
      );

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(changed?.tripId, '2');
    });

    testWidgets('separa crianças dos passageiros no card de solicitação', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCarousel([
          makePendingTrip(
            '1',
            passengers: const [
              TripPassenger(
                name: 'Lia',
                age: 5,
                needsCarSeat: true,
                sortOrder: 1,
              ),
              TripPassenger(
                name: 'Carlos',
                age: 34,
                needsCarSeat: false,
                sortOrder: 2,
              ),
            ],
          ),
        ], selectedTripId: '1'),
      );

      expect(find.text('Passageiros'), findsOneWidget);
      expect(find.text('Carlos — 34 anos'), findsOneWidget);
      expect(find.text('Crianças'), findsOneWidget);
      expect(find.text('Lia — 5 anos (levar cadeirinha)'), findsOneWidget);
    });
  });
}
