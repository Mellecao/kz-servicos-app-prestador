abstract final class DriverLocationPayload {
  static const driverProfileSelect = 'id, provider_profiles!inner(user_id)';

  static String driverProfileIdFromRow(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is String && id.isNotEmpty) return id;
    throw const FormatException('driver_profiles.id ausente');
  }
}
