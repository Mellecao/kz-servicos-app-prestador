class BrazilTime {
  static DateTime fromBackend(String value) {
    return DateTime.parse(value).toUtc().subtract(const Duration(hours: 3));
  }

  static DateTime? maybeFromBackend(String? value) {
    if (value == null || value.isEmpty) return null;
    return fromBackend(value);
  }
}
