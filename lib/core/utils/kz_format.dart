/// Formata valores em Kwanza (AOA): `1.500,00 Kz`.
/// Milhar com ponto, decimal com vírgula, sufixo ` Kz`. Único formatador de
/// moeda do app.
String formatKz(num value) {
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final integer = parts[0];
  final grouped = StringBuffer();
  for (var i = 0; i < integer.length; i++) {
    if (i > 0 && (integer.length - i) % 3 == 0) grouped.write('.');
    grouped.write(integer[i]);
  }
  final isZero = fixed == '0.00';
  final sign = value < 0 && !isZero ? '-' : '';
  return '$sign$grouped,${parts[1]} Kz';
}

/// Versão compacta (milhares) para eixos de gráficos: `1,5k Kz`.
String formatKzCompact(num value) =>
    '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')}k Kz';
