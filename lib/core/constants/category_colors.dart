import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';

/// Cores por categoria de serviço, indexadas pelo nome (pt-AO) vindo do banco.
const Map<String, Color> kCategoryColors = {
  'Eletricista': Color(0xFFE67E22),
  'Canalizador': Color(0xFF3498DB),
  'Pintor': Color(0xFF9B59B6),
  'Limpeza geral': Color(0xFF1ABC9C),
  'Empregada doméstica': Color(0xFF1ABC9C),
  'Montador de Móveis': Color(0xFF8D6E63),
  'Técnico de Informática': Color(0xFF607D8B),
  'Jardineiro': Color(0xFF2ECC71),
  'Pedreiro': Color(0xFF795548),
  'Chaveiro': Color(0xFFF39C12),
  'Ar condicionado': Color(0xFF00BCD4),
  'Carpinteiro': Color(0xFFA1887F),
  'Vidraceiro': Color(0xFF42A5F5),
  'Serralheiro': Color(0xFF78909C),
  'Controlo de pragas': Color(0xFFEF5350),
};

/// Nomes antigos (pt-BR) -> nomes atuais. Mantidos enquanto o banco ainda
/// puder devolver a nomenclatura anterior.
const Map<String, String> kLegacyCategoryNames = {
  'Encanador': 'Canalizador',
  'Faxineira': 'Limpeza geral',
  'Diarista': 'Empregada doméstica',
  'Ar-condicionado': 'Ar condicionado',
  'Marceneiro': 'Carpinteiro',
  'Dedetizador': 'Controlo de pragas',
};

Color categoryColorFor(String name) =>
    kCategoryColors[kLegacyCategoryNames[name] ?? name] ?? AppColors.secondary;
