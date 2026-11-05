class MockTripRequest {
  final String id;
  final String clientName;
  final String origin;
  final String destination;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final DateTime requestedAt;
  final DateTime scheduledAt;
  final DateTime scheduledDate;
  final int passengers;
  final bool hasChildren;
  final int childrenCount;
  final String? childrenDescription;
  final bool hasLuggage;
  final String? luggageDescription;
  final String? observations;
  final double estimatedPrice;
  final double distanceKm;
  final double driverDistanceKm;
  final String paymentMethod;
  final String status;

  const MockTripRequest({
    required this.id,
    required this.clientName,
    required this.origin,
    required this.destination,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.requestedAt,
    required this.scheduledAt,
    required this.scheduledDate,
    required this.passengers,
    required this.hasChildren,
    required this.childrenCount,
    required this.hasLuggage,
    required this.estimatedPrice,
    required this.distanceKm,
    required this.driverDistanceKm,
    required this.paymentMethod,
    required this.status,
    this.childrenDescription,
    this.luggageDescription,
    this.observations,
  });

  static final List<MockTripRequest> pendingRequests = [
    MockTripRequest(
      id: 'req_1',
      clientName: 'Ana Carolina',
      origin: 'Rua Augusta, 1200 - Consolação',
      destination: 'Aeroporto de Guarulhos - Terminal 2',
      originLat: -23.5534,
      originLng: -46.6580,
      destinationLat: -23.4356,
      destinationLng: -46.4731,
      requestedAt: DateTime(2026, 4, 15, 7, 45),
      scheduledAt: DateTime(2026, 4, 15, 8, 30),
      scheduledDate: DateTime(2026, 4, 15, 8, 30),
      passengers: 2,
      hasChildren: false,
      childrenCount: 0,
      hasLuggage: true,
      luggageDescription: '2 malas grandes',
      observations: '2 malas grandes',
      estimatedPrice: 185.00,
      distanceKm: 32.5,
      driverDistanceKm: 4.2,
      paymentMethod: 'Numerário',
      status: 'pending',
    ),
    MockTripRequest(
      id: 'req_2',
      clientName: 'Carlos Mendes',
      origin: 'Av. Paulista, 1578',
      destination: 'Shopping Eldorado',
      originLat: -23.5613,
      originLng: -46.6565,
      destinationLat: -23.5727,
      destinationLng: -46.6951,
      requestedAt: DateTime(2026, 4, 15, 9, 0),
      scheduledAt: DateTime(2026, 4, 15, 10, 0),
      scheduledDate: DateTime(2026, 4, 15, 10, 0),
      passengers: 1,
      hasChildren: false,
      childrenCount: 0,
      hasLuggage: false,
      estimatedPrice: 35.00,
      distanceKm: 6.2,
      driverDistanceKm: 2.8,
      paymentMethod: 'Cartão de Crédito',
      status: 'pending',
    ),
    MockTripRequest(
      id: 'req_3',
      clientName: 'Maria Fernanda',
      origin: 'Rua Oscar Freire, 379',
      destination: 'Hospital Albert Einstein',
      originLat: -23.5622,
      originLng: -46.6693,
      destinationLat: -23.5984,
      destinationLng: -46.7135,
      requestedAt: DateTime(2026, 4, 15, 10, 30),
      scheduledAt: DateTime(2026, 4, 15, 11, 0),
      scheduledDate: DateTime(2026, 4, 15, 11, 0),
      passengers: 3,
      hasChildren: true,
      childrenCount: 1,
      childrenDescription: 'Criança de 4 anos, precisa cadeirinha',
      hasLuggage: false,
      observations: 'Criança de 4 anos, precisa cadeirinha',
      estimatedPrice: 48.00,
      distanceKm: 8.1,
      driverDistanceKm: 5.5,
      paymentMethod: 'TED',
      status: 'pending',
    ),
  ];
}
