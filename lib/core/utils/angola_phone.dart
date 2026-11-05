import 'package:flutter/services.dart';

/// DDI padrão do app (Angola).
const String kAngolaDialCode = '+244';

final RegExp _nonDigits = RegExp(r'\D');
final RegExp _nationalNumber = RegExp(r'^[92]\d{8}$');

/// Dígitos do número nacional (sem +244 / 00244). Só remove o prefixo 244
/// quando é inequívoco: `+244…`, `00244…` ou 12 dígitos começados por 244.
String _nationalDigits(String input) {
  final trimmed = input.trim();
  final digits = trimmed.replaceAll(_nonDigits, '');
  if (digits.startsWith('00244')) return digits.substring(5);
  if (trimmed.startsWith('+244')) return digits.substring(3);
  if (digits.length == 12 && digits.startsWith('244')) {
    return digits.substring(3);
  }
  return digits;
}

/// Móvel: 9 dígitos começados por 9. Fixo de Luanda: 9 dígitos começados por 2.
bool isValidAngolaPhone(String input) =>
    _nationalNumber.hasMatch(_nationalDigits(input));

/// Mostra como `+244 9XX XXX XXX`. Devolve o texto original se for inválido.
String formatAngolaPhone(String input) {
  if (!isValidAngolaPhone(input)) return input;
  final n = _nationalDigits(input);
  return '$kAngolaDialCode ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
}

/// Formato de gravação e de chamadas `tel:`: E.164 sem espaços
/// (`+244923456789`). `null` se o número for inválido.
String? angolaPhoneToE164(String input) => isValidAngolaPhone(input)
    ? '$kAngolaDialCode${_nationalDigits(input)}'
    : null;

/// Número pronto para `tel:`: E.164 se for angolano; números legados (+55,
/// etc.) ficam intactos, apenas sem espaços/pontuação.
String dialablePhone(String input) =>
    angolaPhoneToE164(input) ?? input.replaceAll(RegExp(r'[^0-9+]'), '');

/// Só dígitos, no formato exigido por `wa.me` (sem `+`).
String whatsappDigits(String input) =>
    dialablePhone(input).replaceAll(_nonDigits, '');

/// Máscara de digitação `9XX XXX XXX` (o +244 vem como prefixo fixo do campo).
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _nationalDigits(newValue.text);
    if (digits.length > 9) return oldValue;

    final groups = <String>[
      for (var i = 0; i < digits.length; i += 3)
        digits.substring(i, i + 3 > digits.length ? digits.length : i + 3),
    ];
    final formatted = groups.join(' ');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
