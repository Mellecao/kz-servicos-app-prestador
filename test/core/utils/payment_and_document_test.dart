import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/utils/document_validator.dart';
import 'package:kz_servicos_prestador/core/utils/payment_labels.dart';

void main() {
  group('paymentMethodLabel (pt-AO)', () {
    test('métodos aceites em Angola', () {
      expect(labelForPaymentMethod('cash'), 'Numerário');
      expect(labelForPaymentMethod('debit'), 'Multicaixa / cartão de débito');
      expect(labelForPaymentMethod('credit'), 'Cartão de crédito');
      expect(labelForPaymentMethod('billing'), 'Faturação');
    });

    test('pix legado já não aparece como PIX', () {
      expect(labelForPaymentMethod('pix'), 'Transferência');
    });

    test('nulo vira traço e desconhecido mantém o valor', () {
      expect(labelForPaymentMethod(null), '-');
      expect(labelForPaymentMethod('outro'), 'outro');
    });
  });

  group('isValidBiNif (validação permissiva 9-14 alfanumérico)', () {
    test('aceita BI e NIF típicos', () {
      expect(isValidBiNif('005678901LA041'), isTrue); // BI (14)
      expect(isValidBiNif('5417012345'), isTrue); // NIF (10)
      expect(isValidBiNif('123456789'), isTrue);
    });

    test('ignora espaços e hífens à volta', () {
      expect(isValidBiNif(' 5417012345 '), isTrue);
      expect(isValidBiNif('005678901-LA041'), isTrue);
    });

    test('rejeita curto, longo ou com símbolos', () {
      expect(isValidBiNif('12345678'), isFalse);
      expect(isValidBiNif('123456789012345'), isFalse);
      expect(isValidBiNif('12345678@'), isFalse);
      expect(isValidBiNif(''), isFalse);
    });
  });
}
