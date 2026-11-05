/// Converte timestamps do backend (UTC) para a hora de Luanda
/// (`Africa/Luanda`, UTC+1, sem horário de verão).
class AngolaTime {
  static const Duration offset = Duration(hours: 1);

  static DateTime fromBackend(String value) {
    return DateTime.parse(value).toUtc().add(offset);
  }

  static DateTime? maybeFromBackend(String? value) {
    if (value == null || value.isEmpty) return null;
    return fromBackend(value);
  }
}
