import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/widgets/provider_bottom_nav.dart';

void main() {
  testWidgets(
    'a barra do motorista não ocupa o ecrã todo dentro de um Scaffold',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Center(child: Text('conteúdo da página')),
            bottomNavigationBar: ProviderBottomNav(
              selectedIndex: 0,
              onItemSelected: (_) {},
            ),
          ),
        ),
      );

      final navHeight = tester.getSize(find.byType(ProviderBottomNav)).height;
      expect(navHeight, lessThan(120), reason: 'altura da barra: $navHeight');
      expect(
        tester.getSize(find.text('conteúdo da página')).height,
        greaterThan(0),
      );
    },
  );
}
