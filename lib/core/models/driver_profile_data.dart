class DriverProfileData {
  final String userId;
  final String providerProfileId;
  final String driverProfileId;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final double averageRating;
  final int totalRatings;
  final String? bio;
  final String? bankName;
  final String? bankAgency;
  final String? bankAccount;
  final String? bankAccountType;
  final String? pixKey;
  final String? cnhNumber;
  final String? cnhCategory;
  final DateTime? cnhExpirationDate;
  final bool isAvailable;
  final VehicleData? vehicle;
  final List<ProfilePhotoData> driverPhotos;
  final DateTime createdAt;

  const DriverProfileData({
    required this.userId,
    required this.providerProfileId,
    required this.driverProfileId,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.averageRating,
    required this.totalRatings,
    this.bio,
    this.bankName,
    this.bankAgency,
    this.bankAccount,
    this.bankAccountType,
    this.pixKey,
    this.cnhNumber,
    this.cnhCategory,
    this.cnhExpirationDate,
    required this.isAvailable,
    this.vehicle,
    this.driverPhotos = const [],
    required this.createdAt,
  });

  String get memberSince => createdAt.year.toString();
  List<String> get driverPhotoUrls =>
      driverPhotos.map((photo) => photo.url).toList(growable: false);

  factory DriverProfileData.fromMap(Map<String, dynamic> map) {
    final providerProfile =
        map['provider_profiles'] as Map<String, dynamic>? ?? {};
    final driverProfile =
        providerProfile['driver_profiles'] as Map<String, dynamic>? ?? {};
    final vehiclesList = driverProfile['vehicles'] as List?;
    final driverPhotosList = driverProfile['driver_profile_photos'] as List?;

    VehicleData? vehicle;
    if (vehiclesList != null && vehiclesList.isNotEmpty) {
      final activeVehicle = vehiclesList.cast<Map<String, dynamic>>().firstWhere(
            (v) => v['is_active'] == true,
            orElse: () => vehiclesList.first as Map<String, dynamic>,
          );
      vehicle = VehicleData.fromMap(activeVehicle);
    }

    DateTime? cnhExpiry;
    final cnhExpiryStr = driverProfile['cnh_expiration_date'] as String?;
    if (cnhExpiryStr != null) {
      cnhExpiry = DateTime.tryParse(cnhExpiryStr);
    }

    return DriverProfileData(
      userId: map['id'] as String,
      providerProfileId: providerProfile['id'] as String? ?? '',
      driverProfileId: driverProfile['id'] as String? ?? '',
      name: map['full_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      averageRating:
          (providerProfile['average_rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (providerProfile['total_ratings'] as num?)?.toInt() ?? 0,
      bio: providerProfile['bio'] as String?,
      bankName: providerProfile['bank_name'] as String?,
      bankAgency: providerProfile['bank_agency'] as String?,
      bankAccount: providerProfile['bank_account'] as String?,
      bankAccountType: providerProfile['bank_account_type'] as String?,
      pixKey: providerProfile['bank_pix_key'] as String?,
      cnhNumber: driverProfile['cnh_number'] as String?,
      cnhCategory: driverProfile['cnh_category'] as String?,
      cnhExpirationDate: cnhExpiry,
      isAvailable: driverProfile['is_available'] as bool? ?? false,
      vehicle: vehicle,
      driverPhotos: _photos(driverPhotosList),
      createdAt: DateTime.parse(
        map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static List<ProfilePhotoData> _photos(List? rows) {
    if (rows == null) return const [];
    return rows
        .map((row) => ProfilePhotoData.fromMap(row as Map<String, dynamic>))
        .where((photo) => photo.id.isNotEmpty && photo.url.isNotEmpty)
        .toList(growable: false);
  }
}

class ProfilePhotoData {
  final String id;
  final String url;

  const ProfilePhotoData({required this.id, required this.url});

  factory ProfilePhotoData.fromMap(Map<String, dynamic> map) =>
      ProfilePhotoData(
        id: map['id'] as String? ?? '',
        url: map['photo_url'] as String? ?? '',
      );
}

class VehicleData {
  final String id;
  final String brand;
  final String model;
  final int year;
  final String color;
  final String licensePlate;
  final int passengerCapacity;
  final List<ProfilePhotoData> photos;

  const VehicleData({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.licensePlate,
    required this.passengerCapacity,
    this.photos = const [],
  });

  String get fullModel => '$brand $model $year';
  List<String> get photoUrls =>
      photos.map((photo) => photo.url).toList(growable: false);

  factory VehicleData.fromMap(Map<String, dynamic> map) => VehicleData(
        id: map['id'] as String,
        brand: map['brand'] as String? ?? '',
        model: map['model'] as String? ?? '',
        year: (map['year'] as num?)?.toInt() ?? 0,
        color: map['color'] as String? ?? '',
        licensePlate: map['license_plate'] as String? ?? '',
        passengerCapacity:
            (map['passenger_capacity'] as num?)?.toInt() ?? 4,
        photos: DriverProfileData._photos(map['vehicle_photos'] as List?),
      );
}
