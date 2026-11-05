import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/benefits/presentation/widgets/benefits_banner.dart';

Widget _host(Widget child, {double width = 360}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('BenefitsBanner mostra título e subtítulo em pt-AO', (
    tester,
  ) async {
    await tester.pumpWidget(_host(BenefitsBanner(onTap: () {})));

    expect(find.text('Clube de benefícios'), findsOneWidget);
    expect(find.text('Descontos exclusivos para parceiros'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('BenefitsBanner chama onTap ao tocar', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(BenefitsBanner(onTap: () => taps++)));

    await tester.tap(find.byType(BenefitsBanner));
    expect(taps, 1);
  });

  testWidgets('BenefitsBanner não estoura em ecrã estreito', (tester) async {
    await tester.pumpWidget(_host(BenefitsBanner(onTap: () {}), width: 280));

    expect(tester.takeException(), isNull);
  });
}
