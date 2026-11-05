class MockTripHistory {
  final String id;
  final String clientName;
  final String origin;
  final String destination;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final DateTime completedAt;
  final double price;
  final double distanceKm;
  final double rating;
  final String status;
  final String paymentMethod;
  final String? observations;
  final int durationMinutes;
  final int passengers;
  final bool hasChildren;
  final String? childrenDescription;
  final bool hasLuggage;
  final String? luggageDescription;

  const MockTripHistory({
    required this.id,
    required this.clientName,
    required this.origin,
    required this.destination,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.completedAt,
    required this.price,
    required this.distanceKm,
    required this.rating,
    required this.status,
    required this.paymentMethod,
    required this.durationMinutes,
    required this.passengers,
    required this.hasChildren,
    required this.hasLuggage,
    this.observations,
    this.childrenDescription,
    this.luggageDescription,
  });

  static final List<MockTripHistory> samples = [
    MockTripHistory(
      id: 'hist_1',
      clientName: 'Ana Carolina',
      origin: 'Rua Oscar Freire, 379',
      destination: 'Av. Brigadeiro Faria Lima, 3477',
      originLat: -23.5622,
      originLng: -46.6693,
      destinationLat: -23.5866,
      destinationLng: -46.6822,
      completedAt: DateTime(2026, 4, 14, 18, 45),
      price: 32.50,
      distanceKm: 5.8,
      rating: 5.0,
      status: 'completed',
      paymentMethod: 'Numerário',
      durationMinutes: 18,
      passengers: 1,
      hasChildren: false,
      hasLuggage: false,
    ),
    MockTripHistory(
      id: 'hist_2',
      clientName: 'Pedro Alves',
      origin: 'Estação da Luz',
      destination: 'Parque Ibirapuera',
      originLat: -23.5347,
      originLng: -46.6340,
      destinationLat: -23.5874,
      destinationLng: -46.6576,
      completedAt: DateTime(2026, 4, 14, 14, 20),
      price: 28.00,
      distanceKm: 7.2,
      rating: 4.8,
      status: 'completed',
      paymentMethod: 'Cartão de Crédito',
      observations: 'Levar pelo caminho mais rápido',
      durationMinutes: 25,
      passengers: 2,
      hasChildren: false,
      hasLuggage: false,
    ),
    MockTripHistory(
      id: 'hist_3',
      clientName: 'Lucia Santos',
      origin: 'Shopping Morumbi',
      destination: 'Aeroporto de Congonhas',
      originLat: -23.6228,
      originLng: -46.6986,
      destinationLat: -23.6265,
      destinationLng: -46.6577,
      completedAt: DateTime(2026, 4, 13, 6, 30),
      price: 55.00,
      distanceKm: 12.4,
      rating: 5.0,
      status: 'completed',
      paymentMethod: 'Numerário',
      durationMinutes: 22,
      passengers: 1,
      hasChildren: false,
      hasLuggage: true,
      luggageDescription: '1 mala grande',
    ),
    MockTripHistory(
      id: 'hist_4',
      clientName: 'Roberto Lima',
      origin: 'Av. Paulista, 900',
      destination: 'Vila Olímpia',
      originLat: -23.5613,
      originLng: -46.6565,
      destinationLat: -23.5952,
      destinationLng: -46.6864,
      completedAt: DateTime(2026, 4, 12, 19, 15),
      price: 22.00,
      distanceKm: 4.5,
      rating: 4.5,
      status: 'completed',
      paymentMethod: 'TED',
      durationMinutes: 15,
      passengers: 1,
      hasChildren: false,
      hasLuggage: false,
    ),
    MockTripHistory(
      id: 'hist_5',
      clientName: 'Fernanda Costa',
      origin: 'Pinheiros',
      destination: 'Moema',
      originLat: -23.5670,
      originLng: -46.6918,
      destinationLat: -23.6010,
      destinationLng: -46.6637,
      completedAt: DateTime(2026, 3, 28, 11, 0),
      price: 38.00,
      distanceKm: 9.3,
      rating: 4.9,
      status: 'completed',
      paymentMethod: 'Numerário',
      observations: 'Portão lateral',
      durationMinutes: 28,
      passengers: 3,
      hasChildren: true,
      childrenDescription: '1 criança de 6 anos',
      hasLuggage: false,
    ),
    MockTripHistory(
      id: 'hist_6',
      clientName: 'Marcos Silva',
      origin: 'Tatuapé',
      destination: 'Liberdade',
      originLat: -23.5397,
      originLng: -46.5765,
      destinationLat: -23.5573,
      destinationLng: -46.6344,
      completedAt: DateTime(2026, 3, 25, 8, 45),
      price: 30.00,
      distanceKm: 7.0,
      rating: 5.0,
      status: 'completed',
      paymentMethod: 'Cartão de Crédito',
      durationMinutes: 22,
      passengers: 2,
      hasChildren: false,
      hasLuggage: false,
    ),
  ];
}
