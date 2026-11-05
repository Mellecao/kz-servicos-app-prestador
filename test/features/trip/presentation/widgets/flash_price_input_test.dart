import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/flash_price_input.dart';

void main() {
  testWidgets('emits parsed price on tap Enviar', (tester) async {
    double? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FlashPriceInput(onSubmit: (v) => out = v)),
      ),
    );
    await tester.enterText(find.byType(TextField), '45.5');
    await tester.tap(find.text('Enviar proposta'));
    await tester.pump();
    expect(out, 45.5);
  });

  testWidgets('accepts comma as decimal separator', (tester) async {
    double? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FlashPriceInput(onSubmit: (v) => out = v)),
      ),
    );
    await tester.enterText(find.byType(TextField), '30,75');
    await tester.tap(find.text('Enviar proposta'));
    await tester.pump();
    expect(out, 30.75);
  });

  testWidgets('shows error on invalid input and does not emit', (tester) async {
    double? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FlashPriceInput(onSubmit: (v) => out = v)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Enviar proposta'));
    await tester.pump();
    expect(out, isNull);
    expect(find.text('Preço inválido'), findsOneWidget);
  });

  testWidgets('rejects zero and negative values', (tester) async {
    double? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FlashPriceInput(onSubmit: (v) => out = v)),
      ),
    );
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Enviar proposta'));
    await tester.pump();
    expect(out, isNull);
  });
}
