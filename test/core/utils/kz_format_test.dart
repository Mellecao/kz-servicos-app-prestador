import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/utils/kz_format.dart';

void main() {
  group('formatKz', () {
    test('usa milhar com ponto, decimal com vírgula e sufixo Kz', () {
      expect(formatKz(1500), '1.500,00 Kz');
      expect(formatKz(1234567.891), '1.234.567,89 Kz');
    });

    test('valores pequenos e zero', () {
      expect(formatKz(0), '0,00 Kz');
      expect(formatKz(0.5), '0,50 Kz');
      expect(formatKz(999), '999,00 Kz');
    });

    test('valores negativos mantêm o sinal à frente', () {
      expect(formatKz(-2500.5), '-2.500,50 Kz');
    });

    test('nunca mostra o símbolo R\$', () {
      expect(formatKz(10), isNot(contains(r'R$')));
    });
  });

  group('formatKzCompact', () {
    test('mostra milhares com k para eixos de gráficos', () {
      expect(formatKzCompact(1500), '1,5k Kz');
      expect(formatKzCompact(12000), '12,0k Kz');
      expect(formatKzCompact(0), '0,0k Kz');
    });
  });
}
