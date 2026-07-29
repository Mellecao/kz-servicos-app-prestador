import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduledDirectRepository {
  Future<void> acceptWithPrice(String tripId, double price) async {
    await Supabase.instance.client.rpc(
      'driver_accept_scheduled_direct',
      params: {'trip_id_input': tripId, 'offered_price_input': price},
    );
  }

  Future<void> reject(String tripId) async {
    await Supabase.instance.client.rpc(
      'driver_reject_scheduled_direct',
      params: {'trip_id_input': tripId},
    );
  }
}
