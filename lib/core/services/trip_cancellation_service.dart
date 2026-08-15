import 'package:supabase_flutter/supabase_flutter.dart';

class TripCancellationRequestData {
  final String id;
  final String tripId;
  final String requestedBy;
  final String reason;
  final String status;
  final String? reviewReason;
  final DateTime createdAt;

  const TripCancellationRequestData({
    required this.id,
    required this.tripId,
    required this.requestedBy,
    required this.reason,
    required this.status,
    required this.reviewReason,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory TripCancellationRequestData.fromMap(Map<String, dynamic> map) {
    return TripCancellationRequestData(
      id: map['id'] as String,
      tripId: map['trip_id'] as String,
      requestedBy: map['requested_by'] as String,
      reason: map['reason'] as String,
      status: map['status'] as String,
      reviewReason: map['review_reason'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class TripCancellationService {
  final SupabaseClient _client;

  TripCancellationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static Map<String, dynamic> buildRequestPayload({
    required String tripId,
    required String requestedBy,
    required String reason,
  }) {
    return {
      'trip_id': tripId,
      'requested_by': requestedBy,
      'reason': reason.trim(),
      'status': 'pending',
    };
  }

  Future<TripCancellationRequestData?> getPendingRequest(String tripId) async {
    final row = await _client
        .from('trip_cancellation_requests')
        .select()
        .eq('trip_id', tripId)
        .eq('status', 'pending')
        .maybeSingle();
    if (row == null) return null;
    return TripCancellationRequestData.fromMap(row);
  }

  Future<TripCancellationRequestData> requestCancellation({
    required String tripId,
    required String requestedBy,
    required String reason,
  }) async {
    final row = await _client
        .from('trip_cancellation_requests')
        .insert(
          buildRequestPayload(
            tripId: tripId,
            requestedBy: requestedBy,
            reason: reason,
          ),
        )
        .select()
        .single();
    return TripCancellationRequestData.fromMap(row);
  }
}
