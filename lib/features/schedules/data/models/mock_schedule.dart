enum ScheduleStatus {
  awaitingClientApproval,
  awaitingDriverConfirmation,
  scheduled,
}

class MockSchedule {
  final String id;
  final String clientName;
  final String origin;
  final String destination;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final DateTime scheduledDate;
  final double price;
  final String paymentMethod;
  final int passengers;
  final bool hasChildren;
  final String? childrenDescription;
  final bool hasLuggage;
  final String? luggageDescription;
  final String? clientObservations;
  final ScheduleStatus status;
  final bool hasKzMessage;

  const MockSchedule({
    required this.id,
    required this.clientName,
    required this.origin,
    required this.destination,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.scheduledDate,
    required this.price,
    required this.paymentMethod,
    required this.passengers,
    required this.hasChildren,
    required this.hasLuggage,
    required this.status,
    this.childrenDescription,
    this.luggageDescription,
    this.clientObservations,
    this.hasKzMessage = false,
  });

  String get statusLabel => switch (status) {
    ScheduleStatus.awaitingClientApproval => 'A aguardar aprovação do cliente',
    ScheduleStatus.awaitingDriverConfirmation =>
      'A aguardar confirmação do motorista',
    ScheduleStatus.scheduled => 'Viagem agendada',
  };

  static final List<MockSchedule> samples = [
    MockSchedule(
      id: 'sched_1',
      clientName: 'Ana Carolina Souza',
      origin: 'Av. Paulista, 1578 - Bela Vista',
      destination: 'Aeroporto de Guarulhos - Terminal 2',
      originLat: -23.5613,
      originLng: -46.6560,
      destinationLat: -23.4356,
      destinationLng: -46.4731,
      scheduledDate: DateTime(2026, 4, 18, 6, 30),
      price: 185.00,
      paymentMethod: 'Numerário',
      passengers: 2,
      hasChildren: false,
      hasLuggage: true,
      luggageDescription: '2 malas grandes + 1 mala de mão',
      clientObservations: 'Preciso chegar com 2h de antecedência do voo',
      status: ScheduleStatus.awaitingDriverConfirmation,
      hasKzMessage: true,
    ),
    MockSchedule(
      id: 'sched_2',
      clientName: 'Carlos Eduardo Mendes',
      origin: 'Rua Oscar Freire, 379 - Jardins',
      destination: 'Shopping Morumbi',
      originLat: -23.5626,
      originLng: -46.6710,
      destinationLat: -23.6225,
      destinationLng: -46.6978,
      scheduledDate: DateTime(2026, 4, 17, 14, 0),
      price: 42.00,
      paymentMethod: 'Cartão de Crédito',
      passengers: 1,
      hasChildren: false,
      hasLuggage: false,
      status: ScheduleStatus.awaitingClientApproval,
    ),
    MockSchedule(
      id: 'sched_3',
      clientName: 'Maria Helena Costa',
      origin: 'Hospital Sírio-Libanês',
      destination: 'Rua Vergueiro, 3185 - Vila Mariana',
      originLat: -23.5583,
      originLng: -46.6557,
      destinationLat: -23.5887,
      destinationLng: -46.6359,
      scheduledDate: DateTime(2026, 4, 19, 10, 0),
      price: 35.00,
      paymentMethod: 'TED',
      passengers: 3,
      hasChildren: true,
      childrenDescription: '1 criança de 4 anos (cadeirinha)',
      hasLuggage: false,
      clientObservations: 'Paciente com mobilidade reduzida',
      status: ScheduleStatus.scheduled,
      hasKzMessage: true,
    ),
    MockSchedule(
      id: 'sched_4',
      clientName: 'Roberto Almeida',
      origin: 'Estação Luz',
      destination: 'Parque Ibirapuera - Portão 3',
      originLat: -23.5345,
      originLng: -46.6340,
      destinationLat: -23.5874,
      destinationLng: -46.6576,
      scheduledDate: DateTime(2026, 4, 20, 9, 0),
      price: 28.00,
      paymentMethod: 'Numerário',
      passengers: 2,
      hasChildren: false,
      hasLuggage: false,
      status: ScheduleStatus.awaitingDriverConfirmation,
    ),
  ];
}
