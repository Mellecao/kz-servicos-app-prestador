import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/constants/app_locale.dart';

void main() {
  test('norma linguística é o português europeu/angolano (pt_PT)', () {
    expect(AppLocale.locale, const Locale('pt', 'PT'));
    expect(AppLocale.supported, contains(AppLocale.locale));
    expect(AppLocale.supported, isNot(contains(const Locale('pt', 'BR'))));
  });

  testWidgets('textos do Material saem em pt-PT e não em pt-BR ou inglês', (
    tester,
  ) async {
    late MaterialLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocale.locale,
        supportedLocales: AppLocale.supported,
        localizationsDelegates: AppLocale.delegates,
        home: Builder(
          builder: (context) {
            l10n = MaterialLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(l10n.saveButtonLabel, 'Guardar'); // pt-BR seria "Salvar"
    // Maiúsculas variam entre versões do Flutter ("CANCELAR" / "Cancelar").
    expect(l10n.cancelButtonLabel.toLowerCase(), 'cancelar');
    expect(l10n.okButtonLabel, 'OK');
  });
}
