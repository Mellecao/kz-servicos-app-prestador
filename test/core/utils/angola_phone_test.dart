import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/utils/angola_phone.dart';

TextEditingValue _type(PhoneInputFormatter f, String text, {String old = ''}) {
  return f.formatEditUpdate(
    TextEditingValue(text: old),
    TextEditingValue(text: text),
  );
}

void main() {
  test('DDI padrão é +244', () {
    expect(kAngolaDialCode, '+244');
  });

  group('isValidAngolaPhone', () {
    test('aceita móvel (9 dígitos começados por 9)', () {
      expect(isValidAngolaPhone('923456789'), isTrue);
      expect(isValidAngolaPhone('923 456 789'), isTrue);
      expect(isValidAngolaPhone('+244 923 456 789'), isTrue);
      expect(isValidAngolaPhone('00244923456789'), isTrue);
    });

    test('aceita fixo de Luanda (9 dígitos começados por 2)', () {
      expect(isValidAngolaPhone('222123456'), isTrue);
    });

    test('rejeita números fora do padrão', () {
      expect(isValidAngolaPhone(''), isFalse);
      expect(isValidAngolaPhone('92345678'), isFalse); // 8 dígitos
      expect(isValidAngolaPhone('9234567890'), isFalse); // 10 dígitos
      expect(isValidAngolaPhone('823456789'), isFalse); // não começa por 9 ou 2
      expect(isValidAngolaPhone('(11) 99999-0000'), isFalse); // formato BR
    });
  });

  group('formatAngolaPhone / angolaPhoneToE164', () {
    test('formata como +244 9XX XXX XXX', () {
      expect(formatAngolaPhone('923456789'), '+244 923 456 789');
      expect(formatAngolaPhone('+244923456789'), '+244 923 456 789');
    });

    test('devolve E.164 sem espaços para chamadas tel:', () {
      expect(angolaPhoneToE164('923 456 789'), '+244923456789');
      expect(angolaPhoneToE164('123'), isNull);
    });

    test('número inválido é devolvido sem alteração no formatador', () {
      expect(formatAngolaPhone('123'), '123');
    });
  });

  group('dialablePhone / whatsappDigits', () {
    test('número angolano nacional ou formatado vira E.164', () {
      expect(dialablePhone('923 456 789'), '+244923456789');
      expect(dialablePhone('+244 923 456 789'), '+244923456789');
    });

    test('número legado (+55) fica intacto, só sem espaços', () {
      expect(dialablePhone('+55 11 98588-9577'), '+5511985889577');
    });

    test('whatsappDigits devolve só dígitos, sem acrescentar 55', () {
      expect(whatsappDigits('923 456 789'), '244923456789');
      expect(whatsappDigits('+5511985889577'), '5511985889577');
    });
  });

  group('PhoneInputFormatter', () {
    final formatter = PhoneInputFormatter();

    test('agrupa 3-3-3 enquanto digita', () {
      expect(_type(formatter, '9').text, '9');
      expect(_type(formatter, '92').text, '92');
      expect(_type(formatter, '9234').text, '923 4');
      expect(_type(formatter, '923456').text, '923 456');
      expect(_type(formatter, '923456789').text, '923 456 789');
    });

    test('remove o prefixo +244 ao colar um número completo', () {
      expect(_type(formatter, '+244 923 456 789').text, '923 456 789');
    });

    test('ignora dígitos a mais (máximo 9)', () {
      final old = _type(formatter, '923456789');
      final result = _type(formatter, '9234567890', old: old.text);
      expect(result.text, '923 456 789');
    });
  });
}
