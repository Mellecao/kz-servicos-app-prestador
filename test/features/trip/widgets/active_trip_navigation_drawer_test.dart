import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_navigation_drawer.dart';

void main() {
  testWidgets('menu da corrida envia rota selecionada', (tester) async {
    String? selectedRoute;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveTripNavigationDrawer(
            clientName: 'Maria',
            destinationAddress: 'Av. Brasil, 100',
            onSelectRoute: (route) => selectedRoute = route,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Agendamentos'));

    expect(selectedRoute, '/schedules');
  });
}
