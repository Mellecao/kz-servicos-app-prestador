class BenefitPartner {
  final String id;
  final String merchantName;
  final String merchantAddress;
  final String merchantPhone;
  final String serviceOffered;
  final String serviceDescription;
  final double discountPercent;
  final double originalPrice;
  final bool isActive;

  const BenefitPartner({
    required this.id,
    required this.merchantName,
    required this.merchantAddress,
    this.merchantPhone = '',
    required this.serviceOffered,
    this.serviceDescription = '',
    required this.discountPercent,
    required this.originalPrice,
    required this.isActive,
  });

  double get discountedPrice =>
      originalPrice * (1 - (discountPercent.clamp(0, 100) / 100));

  factory BenefitPartner.fromMap(Map<String, dynamic> map) {
    return BenefitPartner(
      id: map['id'] as String,
      merchantName: map['merchant_name'] as String? ?? '',
      merchantAddress: map['merchant_address'] as String? ?? '',
      merchantPhone: map['merchant_phone'] as String? ?? '',
      serviceOffered: map['service_offered'] as String? ?? '',
      serviceDescription: map['service_description'] as String? ?? '',
      discountPercent: _parseDouble(map['discount_percent']),
      originalPrice: _parseDouble(map['original_price']),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  static double _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
