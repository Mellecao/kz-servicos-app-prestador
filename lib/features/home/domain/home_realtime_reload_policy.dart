class HomeRealtimeReloadPolicy {
  const HomeRealtimeReloadPolicy._();

  static bool candidateChangeTargetsDriver({
    required String driverProfileId,
    Map<String, dynamic>? newRecord,
    Map<String, dynamic>? oldRecord,
  }) {
    return _recordDriverProfileId(newRecord) == driverProfileId ||
        _recordDriverProfileId(oldRecord) == driverProfileId;
  }

  static bool tripChangeTargetsDriver({
    required String driverProfileId,
    Map<String, dynamic>? newRecord,
    Map<String, dynamic>? oldRecord,
  }) {
    return _recordDriverProfileId(newRecord) == driverProfileId ||
        _recordDriverProfileId(oldRecord) == driverProfileId;
  }

  static String? _recordDriverProfileId(Map<String, dynamic>? record) {
    final value = record?['driver_profile_id'];
    return value is String && value.isNotEmpty ? value : null;
  }
}
