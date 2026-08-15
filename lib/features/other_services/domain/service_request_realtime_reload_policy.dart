class ServiceRequestRealtimeReloadPolicy {
  const ServiceRequestRealtimeReloadPolicy._();

  static bool changeTargetsProvider({
    required String providerProfileId,
    required Set<String> providerCategoryIds,
    Map<String, dynamic>? newRecord,
    Map<String, dynamic>? oldRecord,
  }) {
    if (_recordProviderProfileId(newRecord) == providerProfileId ||
        _recordProviderProfileId(oldRecord) == providerProfileId) {
      return true;
    }

    final newProviderId = _recordProviderProfileId(newRecord);
    final newCategoryId = _recordServiceCategoryId(newRecord);
    final newStatus = _recordStatus(newRecord);

    return newProviderId == null &&
        newStatus == 'open' &&
        newCategoryId != null &&
        providerCategoryIds.contains(newCategoryId);
  }

  static String? _recordProviderProfileId(Map<String, dynamic>? record) {
    final value = record?['provider_profile_id'];
    return value is String && value.isNotEmpty ? value : null;
  }

  static String? _recordServiceCategoryId(Map<String, dynamic>? record) {
    final value = record?['service_category_id'];
    return value is String && value.isNotEmpty ? value : null;
  }

  static String? _recordStatus(Map<String, dynamic>? record) {
    final value = record?['status'];
    return value is String && value.isNotEmpty ? value : null;
  }
}
