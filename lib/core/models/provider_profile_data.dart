class ProviderProfileData {
  final String userId;
  final String providerProfileId;
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
  final List<String> serviceCategories;
  final DateTime createdAt;

  const ProviderProfileData({
    required this.userId,
    required this.providerProfileId,
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
    required this.serviceCategories,
    required this.createdAt,
  });

  String get memberSince => createdAt.year.toString();

  factory ProviderProfileData.fromMap(Map<String, dynamic> map) {
    final providerProfile =
        map['provider_profiles'] as Map<String, dynamic>? ?? {};

    final categoryServices =
        providerProfile['provider_category_services'] as List? ?? [];
    final categoryNames = <String>[];
    for (final cs in categoryServices) {
      final cat =
          (cs as Map<String, dynamic>)['service_categories']
              as Map<String, dynamic>?;
      final name = cat?['name'] as String?;
      if (name != null && name.isNotEmpty) categoryNames.add(name);
    }

    final fallbackCategory =
        providerProfile['service_categories'] as Map<String, dynamic>?;
    if (categoryNames.isEmpty && fallbackCategory != null) {
      final n = fallbackCategory['name'] as String?;
      if (n != null) categoryNames.add(n);
    }

    return ProviderProfileData(
      userId: map['id'] as String,
      providerProfileId: providerProfile['id'] as String? ?? '',
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
      serviceCategories: categoryNames,
      createdAt: DateTime.parse(
        map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
