import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/constants/category_colors.dart';

void main() {
  group('categoryColorFor', () {
    test('aceita os nomes novos (pt-AO) das categorias renomeadas', () {
      expect(categoryColorFor('Canalizador'), const Color(0xFF3498DB));
      expect(categoryColorFor('Limpeza geral'), const Color(0xFF1ABC9C));
      expect(categoryColorFor('Empregada doméstica'), const Color(0xFF1ABC9C));
      expect(categoryColorFor('Ar condicionado'), const Color(0xFF00BCD4));
      expect(categoryColorFor('Carpinteiro'), const Color(0xFFA1887F));
      expect(categoryColorFor('Controlo de pragas'), const Color(0xFFEF5350));
    });

    test('mantém os nomes antigos como alias (banco ainda não migrado)', () {
      expect(categoryColorFor('Encanador'), categoryColorFor('Canalizador'));
      expect(categoryColorFor('Faxineira'), categoryColorFor('Limpeza geral'));
      expect(
        categoryColorFor('Diarista'),
        categoryColorFor('Empregada doméstica'),
      );
      expect(
        categoryColorFor('Ar-condicionado'),
        categoryColorFor('Ar condicionado'),
      );
      expect(categoryColorFor('Marceneiro'), categoryColorFor('Carpinteiro'));
      expect(
        categoryColorFor('Dedetizador'),
        categoryColorFor('Controlo de pragas'),
      );
    });

    test('categorias que não mudaram continuam com a mesma cor', () {
      expect(categoryColorFor('Eletricista'), const Color(0xFFE67E22));
      expect(categoryColorFor('Pedreiro'), const Color(0xFF795548));
    });

    test('categoria desconhecida cai na cor secundária', () {
      expect(categoryColorFor('Categoria inexistente'), AppColors.secondary);
    });
  });
}
