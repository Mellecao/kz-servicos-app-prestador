import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/auth/presentation/pages/registration_page.dart';
import 'package:kz_servicos_prestador/features/profile/data/models/mock_provider.dart';

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: RegistrationPage(
        providerType: ProviderType.serviceProvider,
        onComplete: (_) {},
      ),
    ),
  );
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('mostra campos angolanos: BI / NIF e telemóvel', (tester) async {
    await _pumpPage(tester);

    expect(find.text('Registo - Dados pessoais'), findsOneWidget);
    expect(_field('BI / NIF'), findsOneWidget);
    expect(_field('Telemóvel'), findsOneWidget);
    expect(find.text('CPF'), findsNothing);
    expect(find.text('Telefone'), findsNothing);
  });

  testWidgets('rejeita BI/NIF e telemóvel inválidos', (tester) async {
    await _pumpPage(tester);

    await tester.enterText(_field('Nome completo'), 'Ana Paulo');
    await tester.enterText(_field('BI / NIF'), '123');
    await tester.enterText(_field('Telemóvel'), '123');
    await tester.tap(find.text('Próximo'));
    await tester.pump();

    expect(find.text('BI ou NIF inválido'), findsOneWidget);
    expect(find.text('Telemóvel inválido'), findsOneWidget);
    expect(find.text('Registo - Dados pessoais'), findsOneWidget);
  });

  testWidgets('aceita dados válidos e avança para as categorias', (
    tester,
  ) async {
    await _pumpPage(tester);

    await tester.enterText(_field('Nome completo'), 'Ana Paulo');
    await tester.enterText(_field('BI / NIF'), '005678901LA041');
    await tester.enterText(_field('Telemóvel'), '923456789');
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();

    expect(find.text('Registo - Categorias de serviço'), findsOneWidget);
    expect(find.text('Canalizador'), findsOneWidget);
    expect(find.text('Controlo de pragas'), findsOneWidget);
  });
}
