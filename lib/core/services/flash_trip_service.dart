import 'package:supabase_flutter/supabase_flutter.dart';

class FlashTripService {
  final SupabaseClient client;
  FlashTripService({required this.client});

  Future<Map<String, dynamic>> loadIncomingCall(String tripId) async {
    return await client
        .from('trips')
        .select(
          '*, '
          'pickup:addresses!pickup_address_id(*), '
          'dropoff:addresses!dropoff_address_id(*), '
          'client:users!client_id(*)',
        )
        .eq('id', tripId)
        .single();
  }

  Future<void> sendProposal(String tripId, double price) async {
    await client.rpc(
      'driver_send_flash_proposal',
      params: {'p_trip_id': tripId, 'p_price': price},
    );
  }

  Future<void> rejectCall(String tripId) async {
    await client.rpc('reject_flash_call', params: {'p_trip_id': tripId});
  }

  Future<void> recheckConfirm(String tripId) async {
    await client.rpc(
      'driver_flash_recheck_confirm',
      params: {'p_trip_id': tripId},
    );
  }

  Future<void> recheckReject(String tripId) async {
    await client.rpc(
      'driver_flash_recheck_reject',
      params: {'p_trip_id': tripId},
    );
  }

  Stream<Map<String, dynamic>> watchTripStatus(String tripId) {
    return client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((rows) => rows.isEmpty ? <String, dynamic>{} : rows.first);
  }
}
