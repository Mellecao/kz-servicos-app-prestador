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
}
