import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/features/trip/data/services/driver_location_payload.dart';

void main() {
  test('consulta driver profile pelo user_id do provider profile', () {
    expect(
      DriverLocationPayload.driverProfileSelect,
      'id, provider_profiles!inner(user_id)',
    );
  });

  test('extrai id do driver profile retornado pelo Supabase', () {
    expect(
      DriverLocationPayload.driverProfileIdFromRow({
        'id': 'driver-profile-1',
        'provider_profiles': {'user_id': 'user-1'},
      }),
      'driver-profile-1',
    );
  });
}
