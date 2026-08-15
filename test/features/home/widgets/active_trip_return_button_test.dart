import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/home/presentation/widgets/active_trip_return_button.dart';

void main() {
  testWidgets('botao de corrida em andamento chama callback', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveTripReturnButton(
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Corrida em andamento'), findsOneWidget);
    expect(find.text('Voltar'), findsOneWidget);

    await tester.tap(find.byType(ActiveTripReturnButton));

    expect(tapped, isTrue);
  });
}
