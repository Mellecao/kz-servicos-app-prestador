import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/widgets/service_provider_bottom_nav.dart';

void main() {
  testWidgets(
    'por defeito esconde o Clube de benefícios e mantém os índices do router',
    (tester) async {
      var selectedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceProviderBottomNav(
              selectedIndex: 0,
              onItemSelected: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.handyman_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
      expect(find.byIcon(Icons.card_giftcard_rounded), findsNothing);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // O Perfil continua a ser o índice 3 do router (/provider-profile).
      await tester.tap(find.byIcon(Icons.person_rounded));
      expect(selectedIndex, 3);
    },
  );

  testWidgets('shows benefits as the third service provider tab when enabled', (
    tester,
  ) async {
    var selectedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceProviderBottomNav(
            selectedIndex: 0,
            showBenefits: true,
            onItemSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.handyman_rounded), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.card_giftcard_rounded));

    expect(selectedIndex, 2);
  });

  testWidgets(
    'a barra de navegação não ocupa o ecrã todo e deixa espaço ao conteúdo',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Center(child: Text('conteúdo da página')),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: ServiceProviderBottomNav(
                selectedIndex: 0,
                onItemSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final navHeight = tester
          .getSize(find.byType(ServiceProviderBottomNav))
          .height;

      expect(navHeight, lessThan(120), reason: 'altura da barra: $navHeight');
      expect(navHeight, lessThan(screenHeight / 4));

      // O conteúdo da página tem de continuar visível (altura > 0).
      final bodyHeight = tester.getSize(find.text('conteúdo da página')).height;
      expect(bodyHeight, greaterThan(0));
      expect(
        tester.getTopLeft(find.text('conteúdo da página')).dy,
        lessThan(navHeight == 0 ? screenHeight : screenHeight - navHeight),
      );
    },
  );

  testWidgets('tocar num item chama onItemSelected com o índice', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ServiceProviderBottomNav(
            selectedIndex: 0,
            onItemSelected: (i) => tapped = i,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.person_rounded));
    expect(tapped, 3);
  });
}
