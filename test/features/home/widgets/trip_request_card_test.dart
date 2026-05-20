import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/trip_request_card.dart';

final _mockTrip = TripData(
  id: 'trip-1',
  candidateId: 'cand-1',
  clientName: 'Ana',
  origin: 'Rua A',
  destination: 'Rua B',
  originLat: -23.5505,
  originLng: -46.6333,
  destinationLat: -23.5505,
  destinationLng: -46.6333,
  scheduledAt: DateTime(2025, 1, 1),
  passengerCount: 1,
  childrenCount: 0,
  luggageCount: 0,
  status: 'searching_drivers',
);

void main() {
  testWidgets('accept blocked without price', (tester) async {
    double? acceptedPrice;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TripRequestCard(
          request: _mockTrip,
          onAccept: (price) => acceptedPrice = price,
          onReject: () {},
        ),
      ),
    ));
    await tester.tap(find.text('Aceitar solicitação'));
    await tester.pump();
    expect(acceptedPrice, isNull);
    expect(find.text('Informe um valor antes de aceitar'), findsOneWidget);
  });

  testWidgets('accept works with price', (tester) async {
    double? acceptedPrice;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TripRequestCard(
          request: _mockTrip,
          onAccept: (price) => acceptedPrice = price,
          onReject: () {},
        ),
      ),
    ));
    await tester.enterText(find.byKey(const Key('price_input')), '85.00');
    await tester.tap(find.text('Aceitar solicitação'));
    await tester.pump();
    expect(acceptedPrice, equals(85.0));
    expect(find.text('Informe um valor antes de aceitar'), findsNothing);
  });
}
