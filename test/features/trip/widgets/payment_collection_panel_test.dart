import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/widgets/active_trip_panels.dart';

void main() {
  group('PaymentCollectionPanel', () {
    Widget build({VoidCallback? onConfirm}) => MaterialApp(
          home: Scaffold(
            body: PaymentCollectionPanel(
              price: 85.0,
              clientName: 'João Silva',
              paymentMethodLabel: 'PIX',
              onConfirm: onConfirm ?? () {},
            ),
          ),
        );

    testWidgets('exibe valor formatado', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('R\$ 85,00'), findsAtLeastNWidgets(1));
    });

    testWidgets('exibe nome do cliente', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('de João Silva'), findsOneWidget);
    });

    testWidgets('exibe método de pagamento', (tester) async {
      await tester.pumpWidget(build());
      expect(find.text('pelo PIX'), findsOneWidget);
    });

    testWidgets('chama onConfirm ao tocar no botão', (tester) async {
      var called = false;
      await tester.pumpWidget(build(onConfirm: () => called = true));
      await tester.tap(find.text('Pagamento efetuado'));
      expect(called, isTrue);
    });
  });
}
