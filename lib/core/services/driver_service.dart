import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kz_servicos_prestador/core/models/driver_profile_data.dart';

class DriverService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<DriverProfileData?> getDriverProfile(String userId) async {
    try {
      final res = await _client
          .from('users')
          .select(
            '*, provider_profiles(*, driver_profiles(*, driver_profile_photos(*), vehicles(*, vehicle_photos(*))))',
          )
          .eq('id', userId)
          .single();
      debugPrint('[DriverService] profile carregado para $userId');
      return DriverProfileData.fromMap(res);
    } catch (e) {
      debugPrint('[DriverService] getDriverProfile erro: $e');
      return null;
    }
  }

  Future<bool> updateAvailability(String driverProfileId, bool isAvailable) async {
    try {
      await _client
          .from('driver_profiles')
          .update({'is_available': isAvailable})
          .eq('id', driverProfileId);
      return true;
    } catch (e) {
      debugPrint('[DriverService] updateAvailability erro: $e');
      return false;
    }
  }

  Future<bool> deleteDriverProfilePhoto(String photoId) async {
    try {
      await _client.from('driver_profile_photos').delete().eq('id', photoId);
      return true;
    } catch (e) {
      debugPrint('[DriverService] deleteDriverProfilePhoto erro: $e');
      return false;
    }
  }

  Future<bool> deleteVehiclePhoto(String photoId) async {
    try {
      await _client.from('vehicle_photos').delete().eq('id', photoId);
      return true;
    } catch (e) {
      debugPrint('[DriverService] deleteVehiclePhoto erro: $e');
      return false;
    }
  }
}
