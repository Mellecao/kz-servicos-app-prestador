import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/benefits/data/models/benefit_partner.dart';

void main() {
  test('calcula valor com desconto', () {
    const partner = BenefitPartner(
      id: 'benefit-1',
      merchantName: 'Auto Center KZ',
      merchantAddress: 'Av. Brasil, 100',
      serviceOffered: 'Troca de óleo',
      discountPercent: 20,
      originalPrice: 150,
      isActive: true,
    );

    expect(partner.discountedPrice, 120);
  });

  test('parseia registro do backend', () {
    final partner = BenefitPartner.fromMap({
      'id': 'benefit-1',
      'merchant_name': 'Lava Rápido Centro',
      'merchant_address': 'Rua A, 10',
      'service_offered': 'Lavagem completa',
      'discount_percent': 15,
      'original_price': 80,
      'is_active': true,
    });

    expect(partner.merchantName, 'Lava Rápido Centro');
    expect(partner.discountedPrice, 68);
  });
}
