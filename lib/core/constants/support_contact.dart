/// Contactos de suporte do Só Serviços. Único sítio com estes valores.
///
/// ATENÇÃO: são PLACEHOLDERS. Substituir pelo telefone/e-mail reais antes da
/// entrega (pendente de confirmação do utilizador).
abstract final class SupportContact {
  static const String phoneDisplay = '+244 900 000 000';
  static const String phoneE164 = '+244900000000';
  static const String email = 'suporte@soservicos.ao';

  static Uri get telUri => Uri.parse('tel:$phoneE164');

  /// `wa.me` exige o número só com dígitos (sem `+`).
  static Uri get whatsappUri =>
      Uri.parse('https://wa.me/${phoneE164.replaceFirst('+', '')}');

  /// WhatsApp do suporte com mensagem pré-preenchida.
  static Uri whatsappUriWithText(String text) => Uri.parse(
    'https://wa.me/${phoneE164.replaceFirst('+', '')}'
    '?text=${Uri.encodeComponent(text)}',
  );

  static Uri get mailtoUri => Uri.parse('mailto:$email');
}
