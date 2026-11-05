/// Interruptores de funcionalidades do app (único sítio).
abstract final class FeatureFlags {
  /// Clube de benefícios (parceiros e códigos de desconto).
  ///
  /// DESATIVADO até existir a tabela `public.benefit_partners` no banco:
  /// sem ela o ecrã fica vazio (PGRST205). O código do clube foi mantido;
  /// para reativar, crie a tabela e ponha esta flag a `true`.
  static const bool benefitsClubEnabled = false;
}
