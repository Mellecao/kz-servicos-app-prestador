import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/benefits/data/models/benefit_discount_code.dart';

void main() {
  test('gera codigo promocional sequencial legivel', () {
    final code = BenefitDiscountCode.buildCode(sequenceNumber: 42);

    expect(code, 'KZBEN-000042');
  });

  test('gera codigo promocional aleatorio legivel', () {
    final code = BenefitDiscountCode.buildRandomCode();

    expect(code, matches(RegExp(r'^KZ-[A-Z2-9]{6}$')));
  });
}
