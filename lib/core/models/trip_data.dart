class TripData {
  final String tripId;
  final String candidateId;
  final String? clientId;         // trips.client_id (FK → users)
  final String? candidateStatus;  // trip_driver_candidates.status
  final String clientName;
  final String? clientPhone;
  final String origin;
  final String destination;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final DateTime scheduledAt;
  final int passengerCount;
  final int childrenCount;
  final int luggageCount;
  final String? observations;
  final String? driverObservations;
  final double? estimatedPrice;
  final double? finalPrice;
  final double? offeredPrice;
  final String? paymentMethod;
  final String status;
  final DateTime? finishedAt;
  final double? rating;
  final List<TripChild> children;
  final List<TripLuggage> luggage;

  const TripData({
    required this.tripId,
    required this.candidateId,
    this.clientId,
    this.candidateStatus,
    required this.clientName,
    this.clientPhone,
    required this.origin,
    required this.destination,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.scheduledAt,
    required this.passengerCount,
    required this.childrenCount,
    required this.luggageCount,
    this.observations,
    this.driverObservations,
    this.estimatedPrice,
    this.finalPrice,
    this.offeredPrice,
    this.paymentMethod,
    required this.status,
    this.finishedAt,
    this.rating,
    this.children = const [],
    this.luggage = const [],
  });

  double get price => finalPrice ?? estimatedPrice ?? offeredPrice ?? 0;

  bool get hasChildren => childrenCount > 0;
  bool get hasLuggage => luggageCount > 0;

  bool get isAwaitingKzApproval =>
      status == 'searching_drivers' && candidateStatus == 'accepted';

  bool get canDriverRespond =>
      status == 'searching_drivers' || status == 'awaiting_driver_confirmation';

  String get statusLabel {
    if (isAwaitingKzApproval) return 'Aguardando aprovação da KZ';
    return switch (status) {
      'open' => 'Aberta',
      'under_review' => 'Em análise',
      'searching_drivers' => 'Buscando motoristas',
      'awaiting_driver_confirmation' => 'Aguardando confirmação',
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
      origin: pickup['formatted_address'] as String? ?? '',
      destination: dropoff['formatted_address'] as String? ?? '',
      originLat: (pickup['latitude'] as num?)?.toDouble() ?? -23.5505,
      originLng: (pickup['longitude'] as num?)?.toDouble() ?? -46.6333,
      destinationLat: (dropoff['latitude'] as num?)?.toDouble() ?? -23.5505,
      destinationLng: (dropoff['longitude'] as num?)?.toDouble() ?? -46.6333,
      scheduledAt: DateTime.parse(map['scheduled_datetime'] as String),
      passengerCount: (map['passenger_count'] as num?)?.toInt() ?? 1,
      childrenCount: (map['children_count'] as num?)?.toInt() ?? 0,
      luggageCount: (map['luggage_count'] as num?)?.toInt() ?? 0,
      observations: map['observations'] as String?,
      driverObservations: map['driver_observations'] as String?,
      estimatedPrice: (map['estimated_price'] as num?)?.toDouble(),
      finalPrice: (map['final_price'] as num?)?.toDouble(),
      offeredPrice: (map['offered_price'] as num?)?.toDouble(),
      paymentMethod: map['payment_method'] as String?,
      status: map['status'] as String? ?? 'open',
      finishedAt: map['finished_at'] != null
          ? DateTime.parse(map['finished_at'] as String)
          : null,
      rating: rating,
      children: children,
      luggage: luggage,
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
