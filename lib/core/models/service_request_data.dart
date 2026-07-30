class ServiceRequestData {
  final String id;
  final String clientName;
  final String categoryName;
  final String? serviceCategoryId;
  final String? freeformProfession;
  final String description;
  final String address;
  final DateTime serviceDate;
  final double? estimatedPrice;
  final double? finalPrice;
  final String status;
  final String? providerProfileId;
  final bool isPaid;
  final DateTime createdAt;
  final List<String> photoUrls;

  const ServiceRequestData({
    required this.id,
    required this.clientName,
    required this.categoryName,
    required this.serviceCategoryId,
    this.freeformProfession,
    required this.description,
    required this.address,
    required this.serviceDate,
    required this.estimatedPrice,
    required this.finalPrice,
    required this.status,
    required this.providerProfileId,
    required this.isPaid,
    required this.createdAt,
    this.photoUrls = const [],
  });

  double get displayPrice =>
      (finalPrice ?? estimatedPrice ?? 0).toDouble();

  bool get isOpen => providerProfileId == null;

  factory ServiceRequestData.fromMap(Map<String, dynamic> map) {
    final category = map['service_categories'] as Map<String, dynamic>?;
    final addr = map['addresses'] as Map<String, dynamic>?;
    final client = map['client'] as Map<String, dynamic>?;
    final photos = map['service_request_photos'] as List<dynamic>?;
    final sortedPhotos = (photos ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort(
        (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0).compareTo(
          ((b['sort_order'] as num?)?.toInt() ?? 0),
        ),
      );

    return ServiceRequestData(
      id: map['id'] as String,
      clientName: client?['full_name'] as String? ?? '-',
      categoryName: category?['name'] as String? ?? '-',
      serviceCategoryId: map['service_category_id'] as String?,
      freeformProfession: map['freeform_profession'] as String?,
      description: map['description'] as String? ?? '',
      address: addr?['formatted_address'] as String? ?? '-',
      serviceDate: DateTime.parse(
        map['service_date'] as String? ?? DateTime.now().toIso8601String(),
      ),
      estimatedPrice: (map['estimated_price'] as num?)?.toDouble(),
      finalPrice: (map['final_price'] as num?)?.toDouble(),
      status: map['status'] as String? ?? 'open',
      providerProfileId: map['provider_profile_id'] as String?,
      isPaid: map['is_paid'] as bool? ?? false,
      createdAt: DateTime.parse(
        map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      photoUrls: sortedPhotos
          .map((photo) => photo['photo_url'] as String?)
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList(),
    );
  }
}
