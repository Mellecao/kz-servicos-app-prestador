import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/service_request_data.dart';

void main() {
  test('parses service request photo urls by sort order', () {
    final request = ServiceRequestData.fromMap({
      'id': 'request-1',
      'service_category_id': 'category-1',
      'description': 'Trocar piso',
      'service_date': '2026-07-01T12:00:00.000Z',
      'status': 'open',
      'is_paid': false,
      'created_at': '2026-07-01T10:00:00.000Z',
      'service_categories': {'name': 'Pedreiro'},
      'addresses': {'formatted_address': 'Rua A'},
      'client': {'full_name': 'Cliente'},
      'service_request_photos': [
        {'photo_url': 'https://example.com/2.jpg', 'sort_order': 2},
        {'photo_url': 'https://example.com/1.jpg', 'sort_order': 1},
      ],
    });

    expect(request.photoUrls, [
      'https://example.com/1.jpg',
      'https://example.com/2.jpg',
    ]);
  });

  Map<String, dynamic> base() => {
    'id': 'request-2',
    'description': 'Instalar candeeiro',
    'service_date': '2026-11-05T12:00:00.000Z',
    'status': 'searching_provider',
    'is_paid': false,
    'created_at': '2026-11-05T10:00:00.000Z',
    'service_categories': {'name': 'Eletricista'},
    'client': {'full_name': 'Miguel Cliente'},
  };

  test(
    'sem address_id usa a morada que o app Cliente grava em observations',
    () {
      final request = ServiceRequestData.fromMap({
        ...base(),
        'addresses': null,
        'observations': 'Talatona, Luanda',
      });
      expect(request.address, 'Talatona, Luanda');
    },
  );

  test('addresses.formatted_address tem prioridade sobre observations', () {
    final request = ServiceRequestData.fromMap({
      ...base(),
      'addresses': {'formatted_address': 'Rua da Missão 12, Maianga'},
      'observations': 'outra coisa',
    });
    expect(request.address, 'Rua da Missão 12, Maianga');
  });

  test('sem nenhuma morada mostra "-"', () {
    expect(ServiceRequestData.fromMap(base()).address, '-');
  });

  test('service_date (UTC) passa para a hora de Luanda, com virada de dia', () {
    final request = ServiceRequestData.fromMap({
      ...base(),
      'service_date': '2026-11-05T23:30:00.000Z',
    });
    expect(request.serviceDate.day, 6);
    expect(request.serviceDate.hour, 0);
    expect(request.serviceDate.minute, 30);
  });
}
