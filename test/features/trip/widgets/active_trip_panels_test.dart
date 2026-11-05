import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/route_result.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_panels.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/navigation_instruction_banner.dart';

void main() {
  testWidgets('ActiveTripPanel mostra acao de cancelar corrida', (
    tester,
  ) async {
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveTripPanel(
            clientName: 'Maria',
            subtitle: 'A caminho do passageiro',
            phaseColor: Colors.green,
            buttonLabel: 'Cheguei',
            onAdvance: () {},
            onChat: () {},
            onSupportChat: () {},
            onCall: () {},
            onOpenExternalNavigation: () {},
            onReportProblem: () => cancelled = true,
          ),
        ),
      ),
    );

    expect(find.text('Solicitar cancelamento'), findsOneWidget);
    expect(find.text('Relatar um problema'), findsNothing);

    await tester.tap(find.text('Solicitar cancelamento'));
    expect(cancelled, isTrue);
  });

  testWidgets('ActiveTripPanel bloqueia novo pedido enquanto esta em analise', (
    tester,
  ) async {
    var requestedAgain = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveTripPanel(
            clientName: 'Maria',
            subtitle: 'A caminho do passageiro',
            phaseColor: Colors.green,
            buttonLabel: 'Cheguei',
            onAdvance: () {},
            onChat: () {},
            onSupportChat: () {},
            onCall: () {},
            onOpenExternalNavigation: () {},
            onReportProblem: () => requestedAgain = true,
            cancellationPending: true,
          ),
        ),
      ),
    );

    expect(find.text('Cancelamento em análise'), findsNWidgets(2));
    expect(
      find.text('A viagem continua ativa até à resposta da Só Serviços.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelamento em análise').last);
    expect(requestedAgain, isFalse);
  });

  testWidgets('ActiveTripPanel abre o chat com o suporte', (tester) async {
    var openedSupport = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveTripPanel(
            clientName: 'Maria',
            subtitle: 'A caminho do passageiro',
            phaseColor: Colors.green,
            buttonLabel: 'Cheguei',
            onAdvance: () {},
            onChat: () {},
            onSupportChat: () => openedSupport = true,
            onCall: () {},
            onOpenExternalNavigation: () {},
            onReportProblem: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Chat com o suporte'));
    expect(openedSupport, isTrue);
  });

  testWidgets('NavigationInstructionBanner mostra ETA e distancia total', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NavigationInstructionBanner(
            step: RouteStep(
              instruction: 'Vire à direita na Avenida Brasil',
              distanceText: '250 m',
              distanceMeters: 250,
              maneuver: 'turn-right',
              endLocation: LatLng(-23.55, -46.63),
            ),
            phaseColor: Colors.blue,
            routeDistanceText: '7,4 km',
            routeDurationText: '18 min',
          ),
        ),
      ),
    );

    expect(find.text('250 m'), findsOneWidget);
    expect(find.text('18 min'), findsOneWidget);
    expect(find.text('7,4 km'), findsOneWidget);
    expect(find.text('Vire à direita na Avenida Brasil'), findsOneWidget);
  });
}
