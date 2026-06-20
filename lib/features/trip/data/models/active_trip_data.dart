import 'package:kz_servicos_prestador/core/utils/brazil_time.dart';

class ActiveTripData {
  final String id;
  final String candidateId;
  final String clientName;
  final String? clientId;
  final String? clientPhone;
  final String? clientAvatarUrl;
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
  final String status;
  final DateTime? driverArrivedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final bool isDriverPaid;

  const ActiveTripData({
    required this.id,
    required this.candidateId,
    required this.clientName,
    this.clientId,
    this.clientPhone,
    this.clientAvatarUrl,
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
    this.status = 'started',
    this.driverArrivedAt,
    this.startedAt,
    this.finishedAt,
    this.isDriverPaid = false,
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
    return ActiveTripData.fromMap({
      ...trip,
      'candidate_id': candidateId,
      'offered_price': offeredPrice,
    });
  }

  factory ActiveTripData.fromMap(Map<String, dynamic> trip) {
    final pickup = trip['pickup_address'] as Map<String, dynamic>? ?? {};
    final dropoff = trip['dropoff_address'] as Map<String, dynamic>? ?? {};
    final clientUser =
        (trip['client'] ?? trip['users']) as Map<String, dynamic>?;
    final candidates = trip['trip_driver_candidates'];
    final candidate = candidates is List && candidates.isNotEmpty
        ? candidates.first as Map<String, dynamic>
        : <String, dynamic>{};

    String shortAddress(Map<String, dynamic> addr) {
      final formattedAddress = addr['formatted_address'] as String?;
      if (formattedAddress != null && formattedAddress.isNotEmpty) {
        return formattedAddress;
      }
      final street = addr['street'] as String? ?? '';
      final number = addr['number'] as String? ?? '';
      final neighborhood = addr['neighborhood'] as String? ?? '';
      return '$street, $number - $neighborhood';
    }

    DateTime? parseDate(Object? value) {
      if (value == null) return null;
      return BrazilTime.maybeFromBackend(value.toString());
    }

    double parseDouble(Object? value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? fallback;
    }

    final price =
        trip['offered_price'] ??
        candidate['offered_price'] ??
        trip['final_price'] ??
        trip['estimated_price'] ??
        0;

    return ActiveTripData(
      id: trip['id'] as String,
      candidateId:
          trip['candidate_id'] as String? ?? candidate['id'] as String? ?? '',
      clientName: clientUser?['full_name'] as String? ?? 'Cliente',
      clientId: trip['client_id'] as String?,
      clientPhone: clientUser?['phone'] as String?,
      clientAvatarUrl: clientUser?['avatar_url'] as String?,
      pickupAddress: shortAddress(pickup),
      destinationAddress: shortAddress(dropoff),
      pickupLat: parseDouble(pickup['latitude'], -23.5505),
      pickupLng: parseDouble(pickup['longitude'], -46.6333),
      destinationLat: parseDouble(dropoff['latitude'], -23.5505),
      destinationLng: parseDouble(dropoff['longitude'], -46.6333),
      passengerCount: trip['passenger_count'] as int? ?? 1,
      offeredPrice: parseDouble(price, 0),
      paymentMethod: trip['payment_method'] as String?,
      scheduledAt: parseDate(trip['scheduled_datetime']),
      status: trip['status'] as String? ?? 'started',
      driverArrivedAt: parseDate(trip['driver_arrived_at']),
      startedAt: parseDate(trip['started_at']),
      finishedAt: parseDate(trip['finished_at']),
      isDriverPaid: trip['is_driver_paied'] as bool? ?? false,
    );
  }
}
