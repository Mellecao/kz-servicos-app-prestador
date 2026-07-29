import 'package:kz_servicos_prestador/core/utils/brazil_time.dart';

class TripData {
  final String tripId;
  final String candidateId;
  final String? clientId; // trips.client_id (FK → users)
  final String? candidateStatus; // trip_driver_candidates.status
  final String clientName;
  final String? clientPhone;
  final String? clientAvatarUrl;
  final String origin;
  final String destination;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final DateTime scheduledAt;
  final bool isRoundTrip;
  final DateTime? returnAt;
  final int passengerCount;
  final int childrenCount;
  final int luggageCount;
  final String? observations;
  final String? driverObservations;
  final double? estimatedPrice;
  final double? finalPrice;
  final double? offeredPrice;
  final String? priceRejectionReason;
  final double? kzProposedPrice;
  final bool kzProposalLocked;
  final String? paymentMethod;
  final String status;
  final DateTime? finishedAt;
  final double? rating;
  final List<TripChild> children;
  final List<TripLuggage> luggage;
  final List<TripStopData> stops;
  final String tripType;

  const TripData({
    required this.tripId,
    required this.candidateId,
    this.clientId,
    this.candidateStatus,
    required this.clientName,
    this.clientPhone,
    this.clientAvatarUrl,
    required this.origin,
    required this.destination,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.scheduledAt,
    this.isRoundTrip = false,
    this.returnAt,
    required this.passengerCount,
    required this.childrenCount,
    required this.luggageCount,
    this.observations,
    this.driverObservations,
    this.estimatedPrice,
    this.finalPrice,
    this.offeredPrice,
    this.priceRejectionReason,
    this.kzProposedPrice,
    this.kzProposalLocked = false,
    this.paymentMethod,
    required this.status,
    this.finishedAt,
    this.rating,
    this.children = const [],
    this.luggage = const [],
    this.stops = const [],
    this.tripType = 'standard',
  });

  bool get isFlash => tripType == 'flash';

  double get price =>
      finalPrice ?? offeredPrice ?? kzProposedPrice ?? estimatedPrice ?? 0;

  bool get hasChildren => childrenCount > 0;
  bool get hasLuggage => luggageCount > 0;

  bool get isAwaitingKzApproval =>
      status == 'searching_drivers' && candidateStatus == 'accepted';

  bool get canDriverRespond =>
      status == 'searching_drivers' || status == 'awaiting_driver_confirmation';

  TripData copyWith({
    String? tripId,
    String? candidateId,
    String? clientId,
    String? candidateStatus,
    String? clientName,
    String? clientPhone,
    String? clientAvatarUrl,
    String? origin,
    String? destination,
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
    DateTime? scheduledAt,
    bool? isRoundTrip,
    DateTime? returnAt,
    int? passengerCount,
    int? childrenCount,
    int? luggageCount,
    String? observations,
    String? driverObservations,
    double? estimatedPrice,
    double? finalPrice,
    double? offeredPrice,
    String? priceRejectionReason,
    double? kzProposedPrice,
    bool? kzProposalLocked,
    String? paymentMethod,
    String? status,
    DateTime? finishedAt,
    double? rating,
    List<TripChild>? children,
    List<TripLuggage>? luggage,
    List<TripStopData>? stops,
    String? tripType,
  }) {
    return TripData(
      tripId: tripId ?? this.tripId,
      candidateId: candidateId ?? this.candidateId,
      clientId: clientId ?? this.clientId,
      candidateStatus: candidateStatus ?? this.candidateStatus,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientAvatarUrl: clientAvatarUrl ?? this.clientAvatarUrl,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isRoundTrip: isRoundTrip ?? this.isRoundTrip,
      returnAt: returnAt ?? this.returnAt,
      passengerCount: passengerCount ?? this.passengerCount,
      childrenCount: childrenCount ?? this.childrenCount,
      luggageCount: luggageCount ?? this.luggageCount,
      observations: observations ?? this.observations,
      driverObservations: driverObservations ?? this.driverObservations,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      priceRejectionReason: priceRejectionReason ?? this.priceRejectionReason,
      kzProposedPrice: kzProposedPrice ?? this.kzProposedPrice,
      kzProposalLocked: kzProposalLocked ?? this.kzProposalLocked,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      finishedAt: finishedAt ?? this.finishedAt,
      rating: rating ?? this.rating,
      children: children ?? this.children,
      luggage: luggage ?? this.luggage,
      stops: stops ?? this.stops,
      tripType: tripType ?? this.tripType,
    );
  }

  String get statusLabel {
    if (isAwaitingKzApproval) return 'Aguardando aprovação da KZ';
    return switch (status) {
      'open' => 'Aberta',
      'under_review' => 'Em análise',
      'searching_drivers' => 'Buscando motoristas',
      'awaiting_driver_confirmation' => 'Aguardando re-check do motorista',
      'awaiting_client_confirmation' => 'Aguardando passageiro aceitar',
      'scheduled' => 'Agendada',
      'started' => 'Em andamento',
      'finished' => 'Finalizado',
      'cancelled' => 'Cancelado',
      _ => status,
    };
  }

  String get paymentMethodLabel => switch (paymentMethod) {
    'pix' => 'PIX',
    'debit' => 'Débito',
    'credit' => 'Crédito',
    'cash' => 'Dinheiro',
    'billing' => 'Faturamento',
    _ => paymentMethod ?? '-',
  };

  factory TripData.fromMap(Map<String, dynamic> map) {
    final pickup = map['pickup_address'] as Map<String, dynamic>? ?? {};
    final dropoff = map['dropoff_address'] as Map<String, dynamic>? ?? {};
    final clientMap = map['client'] as Map<String, dynamic>? ?? {};

    final rawChildren = map['trip_children'];
    final rawLuggage = map['trip_luggage'];
    final rawStops = map['trip_stops'];

    final children = rawChildren is List
        ? rawChildren
              .map((e) => TripChild.fromMap(e as Map<String, dynamic>))
              .toList()
        : <TripChild>[];

    final luggage = rawLuggage is List
        ? rawLuggage
              .map((e) => TripLuggage.fromMap(e as Map<String, dynamic>))
              .toList()
        : <TripLuggage>[];
    final stops = rawStops is List
        ? (rawStops
              .map((e) => TripStopData.fromMap(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order)))
        : <TripStopData>[];

    final ratingsRaw = map['ratings'];
    double? rating;
    if (ratingsRaw is List && ratingsRaw.isNotEmpty) {
      rating = (ratingsRaw.first['score'] as num?)?.toDouble();
    } else if (ratingsRaw is Map) {
      rating = (ratingsRaw['score'] as num?)?.toDouble();
    }

    return TripData(
      tripId: map['id'] as String,
      candidateId: map['candidate_id'] as String? ?? '',
      clientId: map['client_id'] as String?,
      candidateStatus: map['candidate_status'] as String?,
      clientName: clientMap['full_name'] as String? ?? 'Cliente',
      clientPhone: clientMap['phone'] as String?,
      clientAvatarUrl: clientMap['avatar_url'] as String?,
      origin: pickup['formatted_address'] as String? ?? '',
      destination: dropoff['formatted_address'] as String? ?? '',
      originLat: (pickup['latitude'] as num?)?.toDouble() ?? -23.5505,
      originLng: (pickup['longitude'] as num?)?.toDouble() ?? -46.6333,
      destinationLat: (dropoff['latitude'] as num?)?.toDouble() ?? -23.5505,
      destinationLng: (dropoff['longitude'] as num?)?.toDouble() ?? -46.6333,
      scheduledAt: BrazilTime.fromBackend(map['scheduled_datetime'] as String),
      isRoundTrip: map['is_round_trip'] as bool? ?? false,
      returnAt: map['return_datetime'] != null
          ? BrazilTime.fromBackend(map['return_datetime'] as String)
          : null,
      passengerCount: (map['passenger_count'] as num?)?.toInt() ?? 1,
      childrenCount: (map['children_count'] as num?)?.toInt() ?? 0,
      luggageCount: (map['luggage_count'] as num?)?.toInt() ?? 0,
      observations: map['observations'] as String?,
      driverObservations: map['driver_observations'] as String?,
      estimatedPrice: (map['estimated_price'] as num?)?.toDouble(),
      finalPrice: (map['final_price'] as num?)?.toDouble(),
      offeredPrice: (map['offered_price'] as num?)?.toDouble(),
      priceRejectionReason: map['price_rejection_reason'] as String?,
      kzProposedPrice: (map['kz_proposed_price'] as num?)?.toDouble(),
      kzProposalLocked: map['kz_proposal_locked'] as bool? ?? false,
      paymentMethod: map['payment_method'] as String?,
      status: map['status'] as String? ?? 'open',
      finishedAt: map['finished_at'] != null
          ? BrazilTime.fromBackend(map['finished_at'] as String)
          : null,
      rating: rating,
      children: children,
      luggage: luggage,
      stops: stops,
      tripType: map['trip_type'] as String? ?? 'standard',
    );
  }
}

class TripStopData {
  final int order;
  final String address;
  final double latitude;
  final double longitude;

  const TripStopData({
    required this.order,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory TripStopData.fromMap(Map<String, dynamic> map) {
    final address = map['addresses'] as Map<String, dynamic>? ?? {};
    return TripStopData(
      order: (map['stop_order'] as num?)?.toInt() ?? 0,
      address: address['formatted_address'] as String? ?? 'Parada',
      latitude: (address['latitude'] as num?)?.toDouble() ?? -23.5505,
      longitude: (address['longitude'] as num?)?.toDouble() ?? -46.6333,
    );
  }
}

class TripChild {
  final int age;
  final bool needsCarSeat;

  const TripChild({required this.age, required this.needsCarSeat});

  factory TripChild.fromMap(Map<String, dynamic> map) => TripChild(
    age: (map['age'] as num?)?.toInt() ?? 0,
    needsCarSeat: map['needs_car_seat'] as bool? ?? false,
  );
}

class TripLuggage {
  final String size;
  final int quantity;

  const TripLuggage({required this.size, required this.quantity});

  factory TripLuggage.fromMap(Map<String, dynamic> map) => TripLuggage(
    size: map['size'] as String? ?? 'small',
    quantity: (map['quantity'] as num?)?.toInt() ?? 1,
  );
}
