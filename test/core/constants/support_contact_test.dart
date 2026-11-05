import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/constants/support_contact.dart';
import 'package:kz_servicos_prestador/core/utils/angola_phone.dart';

void main() {
  test('contacto de suporte usa o placeholder angolano +244 900 000 000', () {
    expect(SupportContact.phoneDisplay, '+244 900 000 000');
    expect(SupportContact.phoneE164, '+244900000000');
  });

  test('exibição e E.164 do suporte são coerentes entre si', () {
    expect(
      angolaPhoneToE164(SupportContact.phoneDisplay),
      SupportContact.phoneE164,
    );
  });

  test('links tel: e WhatsApp derivam do mesmo número', () {
    expect(SupportContact.telUri.toString(), 'tel:+244900000000');
    expect(SupportContact.whatsappUri.toString(), 'https://wa.me/244900000000');
    expect(SupportContact.mailtoUri.scheme, 'mailto');
  });

  test('não restam contactos do Brasil', () {
    final all = [
      SupportContact.phoneDisplay,
      SupportContact.phoneE164,
      SupportContact.email,
    ].join(' ');
    expect(all, isNot(contains('+55')));
    expect(all, isNot(contains('.com.br')));
  });

  test('whatsappUriWithText usa o número do suporte e codifica o texto', () {
    final uri = SupportContact.whatsappUriWithText('Olá, preciso de ajuda');
    expect(
      uri.toString(),
      'https://wa.me/244900000000?text=Ol%C3%A1%2C%20preciso%20de%20ajuda',
    );
  });
}
