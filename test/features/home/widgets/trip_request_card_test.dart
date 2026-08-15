import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/trip_request_card.dart';

final _mockTrip = TripData(
  tripId: 'trip-1',
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRequestCard(
            request: _mockTrip,
            onAccept: (price) => acceptedPrice = price,
            onReject: () {},
            onShowDetails: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aceitar solicitação'));
    await tester.pump();
    expect(acceptedPrice, isNull);
    expect(find.text('Informe um valor antes de aceitar'), findsOneWidget);
  });

  testWidgets('accept works with price', (tester) async {
    double? acceptedPrice;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRequestCard(
            request: _mockTrip,
            onAccept: (price) => acceptedPrice = price,
            onReject: () {},
            onShowDetails: () {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('price_input')), '85.00');
    await tester.tap(find.text('Aceitar solicitação'));
    await tester.pump();
    expect(acceptedPrice, equals(85.0));
    expect(find.text('Informe um valor antes de aceitar'), findsNothing);
  });

  testWidgets('notifies price field focus changes', (tester) async {
    final focusChanges = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRequestCard(
            request: _mockTrip,
            onAccept: (_) {},
            onReject: () {},
            onShowDetails: () {},
            onPriceFieldFocusChanged: focusChanges.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('price_input')));
    await tester.pump();

    expect(focusChanges, equals([true]));
  });

  testWidgets('shows details button and calls explicit callback', (
    tester,
  ) async {
    var detailsTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRequestCard(
            request: _mockTrip,
            onAccept: (_) {},
            onReject: () {},
            onShowDetails: () => detailsTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar detalhes'));

    expect(detailsTapped, isTrue);
  });

  testWidgets('compact mode hides details button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRequestCard(
            request: _mockTrip,
            onAccept: (_) {},
            onReject: () {},
            onShowDetails: () {},
            compact: true,
            showDetailsButton: false,
          ),
        ),
      ),
    );

    expect(find.text('Mostrar detalhes'), findsNothing);
  });

  testWidgets('shows departure and return time in request summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRequestCard(
            request: _mockTrip.copyWith(
              scheduledAt: DateTime(2025, 7, 11, 15, 0),
              isRoundTrip: true,
              returnAt: DateTime(2025, 7, 11, 17, 30),
            ),
            onAccept: (_) {},
            onReject: () {},
            onShowDetails: () {},
          ),
        ),
      ),
    );

    expect(
      find.text('Partida 11/07 às 15:00 • Retorno 11/07 às 17:30'),
      findsOneWidget,
    );
  });

  testWidgets('reduced effects mode removes heavy card shadow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRequestCard(
            request: _mockTrip,
            onAccept: (_) {},
            onReject: () {},
            onShowDetails: () {},
            reduceEffects: true,
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.boxShadow, isNull);
  });

  testWidgets('re-check explica que passageiro confirmou a corrida', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRequestCard(
            request: _mockTrip.copyWith(status: 'awaiting_driver_confirmation'),
            onAccept: (_) {},
            onReject: () {},
            onShowDetails: () {},
          ),
        ),
      ),
    );

    expect(
      find.text(
        'O passageiro confirmou a corrida. Confira os detalhes e confirme se ainda quer manter o agendamento.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pedido direto permite motorista informar proposta', (
    tester,
  ) async {
    double? acceptedPrice;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRequestCard(
            request: _mockTrip.copyWith(
              status: 'awaiting_driver_confirmation',
              candidateStatus: 'pending',
              tripType: 'scheduled_choose_driver',
            ),
            onAccept: (price) => acceptedPrice = price,
            onReject: () {},
            onShowDetails: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('price_input')), findsOneWidget);
    expect(
      find.text(
        'O passageiro confirmou a corrida. Confira os detalhes e confirme se ainda quer manter o agendamento.',
      ),
      findsNothing,
    );

    await tester.enterText(find.byKey(const Key('price_input')), '90,50');
    await tester.tap(find.text('Aceitar solicitação'));
    await tester.pump();

    expect(acceptedPrice, 90.5);
  });
}
