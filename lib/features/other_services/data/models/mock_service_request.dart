import 'package:flutter/material.dart';

enum ServiceRequestStatus { pending, accepted, rejected }

class MockServiceRequest {
  final String id;
  final String clientName;
  final String category;
  final Color categoryColor;
  final String problemDescription;
  final String address;
  final DateTime scheduledDate;
  final double estimatedValue;
  final ServiceRequestStatus status;

  const MockServiceRequest({
    required this.id,
    required this.clientName,
    required this.category,
    required this.categoryColor,
    required this.problemDescription,
    required this.address,
    required this.scheduledDate,
    required this.estimatedValue,
    required this.status,
  });

  static final List<MockServiceRequest> samples = [
    MockServiceRequest(
      id: 'sr_1',
      clientName: 'Carlos Eduardo',
      category: 'Eletricista',
      categoryColor: const Color(0xFFE67E22),
      problemDescription:
          'Troca de fiação antiga no apartamento, '
          '3 cômodos com problemas de curto-circuito.',
      address: 'Rua Augusta, 1200 - Consolação, SP',
      scheduledDate: DateTime(2026, 4, 17, 14, 0),
      estimatedValue: 350.00,
      status: ServiceRequestStatus.pending,
    ),
    MockServiceRequest(
      id: 'sr_2',
      clientName: 'Ana Beatriz',
      category: 'Canalizador',
      categoryColor: const Color(0xFF3498DB),
      problemDescription:
          'Vazamento embaixo da pia da cozinha, '
          'torneira pingando e cano com ferrugem.',
      address: 'Av. Paulista, 900 - Bela Vista, SP',
      scheduledDate: DateTime(2026, 4, 18, 9, 30),
      estimatedValue: 200.00,
      status: ServiceRequestStatus.pending,
    ),
    MockServiceRequest(
      id: 'sr_3',
      clientName: 'Roberto Lima',
      category: 'Eletricista',
      categoryColor: const Color(0xFFE67E22),
      problemDescription:
          'Instalação de tomadas novas e quadro de '
          'disjuntores no escritório.',
      address: 'Rua Oscar Freire, 560 - Pinheiros, SP',
      scheduledDate: DateTime(2026, 4, 19, 10, 0),
      estimatedValue: 480.00,
      status: ServiceRequestStatus.accepted,
    ),
    MockServiceRequest(
      id: 'sr_4',
      clientName: 'Fernanda Oliveira',
      category: 'Pintor',
      categoryColor: const Color(0xFF9B59B6),
      problemDescription:
          'Pintura completa de sala e dois quartos, '
          'paredes com infiltração já tratada.',
      address: 'Rua Haddock Lobo, 350 - Cerqueira César, SP',
      scheduledDate: DateTime(2026, 4, 20, 8, 0),
      estimatedValue: 1200.00,
      status: ServiceRequestStatus.pending,
    ),
  ];
}
