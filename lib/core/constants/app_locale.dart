import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Idioma do app: português de Angola (norma europeia).
///
/// `pt_AO` não existe no `flutter_localizations`/`intl`, por isso usa-se
/// `pt_PT` como fallback (textos do Material, datas dd/MM/yyyy, 24 h).
abstract final class AppLocale {
  static const Locale locale = Locale('pt', 'PT');

  static const List<Locale> supported = [locale];

  static const List<LocalizationsDelegate<dynamic>> delegates =
      GlobalMaterialLocalizations.delegates;
}
