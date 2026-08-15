import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/widgets/service_provider_bottom_nav.dart';

void main() {
  testWidgets('shows benefits as the third service provider tab', (tester) async {
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
    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.card_giftcard_rounded));

    expect(selectedIndex, 2);
  });
}
