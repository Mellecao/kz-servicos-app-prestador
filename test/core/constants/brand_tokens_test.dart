import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/constants/app_brand.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

void main() {
  group('AppColors (marca Só Serviços)', () {
    test('primária laranja e variações', () {
      expect(AppColors.highlight, const Color(0xFFFF9A52));
      expect(AppColors.highlightDark, const Color(0xFFE68B4A));
      expect(AppColors.highlightLight, const Color(0xFFFFB27A));
    });

    test('rosa, texto sobre primária e fundo escuro da marca', () {
      expect(AppColors.brandPink, const Color(0xFFE54C65));
      expect(AppColors.onHighlight, const Color(0xFF1F2430));
      expect(AppColors.brandDark, const Color(0xFF16161D));
    });

    test('degradê da marca vai do rosa ao laranja', () {
      final gradient = AppColors.brandGradient;
      expect(gradient.colors, [AppColors.brandPink, AppColors.highlight]);
    });

    test('mantém o azul secundário', () {
      expect(AppColors.secondary, const Color(0xFF2261FE));
    });
  });

  group('AppBrand', () {
    test('nome e slogan da marca', () {
      expect(AppBrand.name, 'Só Serviços');
      expect(AppBrand.appName, 'Só Serviços Prestador');
      expect(AppBrand.tagline, 'Serviços de apoio ao domicílio');
    });

    test('logos apontam para os assets de marca', () {
      expect(AppBrand.logoWhite, 'assets/brand/logo-horizontal-white.png');
      expect(AppBrand.logoDark, 'assets/brand/logo-horizontal-dark.png');
      expect(AppBrand.logoIcon, 'assets/brand/logo-icon.png');
    });
  });
}
