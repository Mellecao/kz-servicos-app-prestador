import 'dart:math';

class BenefitDiscountCode {
  final String id;
  final String benefitPartnerId;
  final String driverProfileId;
  final String code;
  final int sequenceNumber;
  final DateTime createdAt;

  const BenefitDiscountCode({
    required this.id,
    required this.benefitPartnerId,
    required this.driverProfileId,
    required this.code,
    required this.sequenceNumber,
    required this.createdAt,
  });

  static String buildCode({required int sequenceNumber}) {
    return 'KZBEN-${sequenceNumber.toString().padLeft(6, '0')}';
  }

  static String buildRandomCode({Random? random}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final generator = random ?? Random.secure();
    final suffix = List.generate(
      6,
      (_) => chars[generator.nextInt(chars.length)],
    ).join();
    return 'KZ-$suffix';
  }

  factory BenefitDiscountCode.fromMap(Map<String, dynamic> map) {
    return BenefitDiscountCode(
      id: map['id'] as String,
      benefitPartnerId: map['benefit_partner_id'] as String,
      driverProfileId: map['driver_profile_id'] as String,
      code: map['code'] as String,
      sequenceNumber: map['sequence_number'] as int? ?? 0,
      createdAt:
          DateTime.tryParse('${map['created_at']}') ?? DateTime.now().toUtc(),
    );
  }
}
