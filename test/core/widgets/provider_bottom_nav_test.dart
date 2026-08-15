import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/widgets/provider_bottom_nav.dart';

void main() {
  testWidgets('shows schedule badge count above agenda icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProviderBottomNav(
            selectedIndex: 0,
            scheduleBadgeCount: 3,
            onItemSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('caps schedule badge count at 99+', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProviderBottomNav(
            selectedIndex: 0,
            scheduleBadgeCount: 100,
            onItemSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('expõe atalho do chat KZ no quinto item', (tester) async {
    var selectedIndex = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProviderBottomNav(
            selectedIndex: 0,
            onItemSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.support_agent_rounded));
    expect(selectedIndex, 4);
  });
}
