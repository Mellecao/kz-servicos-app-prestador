class ActiveTripData {
  final String id;
  final String candidateId;
  final String clientName;
  final String? clientId;
  final String? clientPhone;
  final String pickupAddress;
  final String destinationAddress;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;
  final int passengerCount;
  final double offeredPrice;
  final String? paymentMethod;
  final DateTime? scheduledAt;

  const ActiveTripData({
    required this.id,
    required this.candidateId,
    required this.clientName,
    this.clientId,
    this.clientPhone,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.passengerCount,
    required this.offeredPrice,
    this.paymentMethod,
    this.scheduledAt,
  });

  String get paymentMethodLabel => switch (paymentMethod) {
        'pix' => 'PIX',
        'debit' => 'Débito',
        'credit' => 'Crédito',
        'cash' => 'Dinheiro',
        'billing' => 'Faturamento',
        _ => paymentMethod ?? '-',
      };

  factory ActiveTripData.fromSupabase(
    Map<String, dynamic> trip,
    String candidateId,
    double offeredPrice,
  ) {
    final pickup = trip['pickup_address'] as Map<String, dynamic>;
    final dropoff = trip['dropoff_address'] as Map<String, dynamic>;
    final clientUser = trip['users'] as Map<String, dynamic>?;

    String shortAddress(Map<String, dynamic> addr) {
      final street = addr['street'] as String? ?? '';
      final number = addr['number'] as String? ?? '';
      final neighborhood = addr['neighborhood'] as String? ?? '';
      return '$street, $number - $neighborhood';
    }

    return ActiveTripData(
      id: trip['id'] as String,
      candidateId: candidateId,
      clientName: clientUser?['full_name'] as String? ?? 'Cliente',
      clientId: trip['client_id'] as String?,
      clientPhone: clientUser?['phone'] as String?,
      pickupAddress: shortAddress(pickup),
      destinationAddress: shortAddress(dropoff),
      pickupLat: double.parse('${pickup['latitude']}'),
      pickupLng: double.parse('${pickup['longitude']}'),
      destinationLat: double.parse('${dropoff['latitude']}'),
      destinationLng: double.parse('${dropoff['longitude']}'),
      passengerCount: trip['passenger_count'] as int? ?? 1,
      offeredPrice: offeredPrice,
      paymentMethod: trip['payment_method'] as String?,
      scheduledAt: trip['scheduled_datetime'] != null
          ? DateTime.parse(trip['scheduled_datetime'] as String)
          : null,
    );
  }
}
