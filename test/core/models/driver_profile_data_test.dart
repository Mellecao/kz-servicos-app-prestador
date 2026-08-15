import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/models/driver_profile_data.dart';

void main() {
  test('preserva ids e urls das fotos do motorista e do veiculo', () {
    final profile = DriverProfileData.fromMap({
      'id': 'user-1',
      'full_name': 'Maria Motorista',
      'email': 'maria@example.com',
      'created_at': '2026-06-01T10:00:00.000Z',
      'provider_profiles': {
        'id': 'provider-1',
        'average_rating': 4.8,
        'total_ratings': 12,
        'driver_profiles': {
          'id': 'driver-1',
          'is_available': true,
          'driver_profile_photos': [
            {'id': 'driver-photo-1', 'photo_url': 'https://cdn/driver-1.jpg'},
          ],
          'vehicles': [
            {
              'id': 'vehicle-1',
              'brand': 'Toyota',
              'model': 'Corolla',
              'year': 2024,
              'color': 'Prata',
              'license_plate': 'ABC1D23',
              'passenger_capacity': 4,
              'is_active': true,
              'vehicle_photos': [
                {
                  'id': 'vehicle-photo-1',
                  'photo_url': 'https://cdn/vehicle-1.jpg',
                },
              ],
            },
          ],
        },
      },
    });

    expect(profile.driverPhotos.single.id, 'driver-photo-1');
    expect(profile.driverPhotos.single.url, 'https://cdn/driver-1.jpg');
    expect(profile.driverPhotoUrls, ['https://cdn/driver-1.jpg']);
    expect(profile.vehicle?.photos.single.id, 'vehicle-photo-1');
    expect(profile.vehicle?.photos.single.url, 'https://cdn/vehicle-1.jpg');
    expect(profile.vehicle?.photoUrls, ['https://cdn/vehicle-1.jpg']);
  });
}
