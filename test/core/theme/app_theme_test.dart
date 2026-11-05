import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/theme/app_theme.dart';

void main() {
  test('tema claro usa o laranja da marca com texto escuro por cima', () {
    final scheme = AppTheme.light.colorScheme;

    expect(scheme.primary, AppColors.highlight);
    expect(scheme.onPrimary, AppColors.onHighlight);
    expect(scheme.primaryContainer, AppColors.highlightLight);
    expect(scheme.onPrimaryContainer, AppColors.onHighlight);
  });
}
