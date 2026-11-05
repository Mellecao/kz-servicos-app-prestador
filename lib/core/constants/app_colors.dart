import 'package:flutter/material.dart';

/// Tokens de cor da marca "Só Serviços". Único sítio onde as cores da marca
/// são definidas; o resto do app referencia estes valores.
abstract final class AppColors {
  static const Color background = Color(0xFFF1F0F0);

  /// Laranja primário da marca (substitui o amarelo antigo).
  static const Color highlight = Color(0xFFFF9A52);
  static const Color highlightDark = Color(0xFFE68B4A);
  static const Color highlightLight = Color(0xFFFFB27A);
  static const Color brandPink = Color(0xFFE54C65);

  /// Texto/ícones sobre a cor primária. Nunca usar branco sobre o laranja.
  static const Color onHighlight = Color(0xFF1F2430);

  /// Fundo escuro do ícone, do splash nativo e do splash Flutter.
  static const Color brandDark = Color(0xFF16161D);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandPink, highlight],
  );

  static const Color secondary = Color(0xFF2261FE);
  static const Color textPrimary = Color(0xFF5C5956);
  static const Color textSecondary = Color(0xFF9E9B98);
  static const Color white = Colors.white;
}
