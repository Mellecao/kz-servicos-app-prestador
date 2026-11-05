import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/widgets/brand_backdrop.dart';

void main() {
  testWidgets('BrandBackdrop mostra o conteúdo sobre o fundo escuro da marca', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BrandBackdrop(child: Center(child: Text('conteúdo'))),
      ),
    );

    expect(find.text('conteúdo'), findsOneWidget);

    final base = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(BrandBackdrop),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(base.color, AppColors.brandDark);
    expect(find.byType(Image), findsNothing);
  });
}
