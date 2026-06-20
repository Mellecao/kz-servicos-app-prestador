import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class ChatEntryData {
  final String referenceId;
  final bool isTrip;
  final String? roomId;
  final String clientId;
  final String clientName;
  final String? clientAvatarUrl;
  final String title;
  final String subtitle;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ChatEntryData({
    required this.referenceId,
    required this.isTrip,
    this.roomId,
    required this.clientId,
    required this.clientName,
    this.clientAvatarUrl,
    required this.title,
    required this.subtitle,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
  });
}

class ChatMessageData {
  final String id;
  final String senderId;
  final String message;
  final bool isRead;
  final DateTime sentAt;

  const ChatMessageData({
    required this.id,
    required this.senderId,
    required this.message,
    required this.isRead,
    required this.sentAt,
  });

  factory ChatMessageData.fromMap(Map<String, dynamic> map) {
    return ChatMessageData(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      message: map['message'] as String,
      isRead: map['is_read'] as bool? ?? false,
      sentAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class ChatPageArgs {
  final String roomId;
  final String title;
  final String subtitle;
  final String clientName;
  final String? clientAvatarUrl;
  final String clientId;
  final String? tripId;
  final String? serviceRequestId;

  const ChatPageArgs({
    required this.roomId,
    required this.title,
    required this.subtitle,
    required this.clientName,
    this.clientAvatarUrl,
    required this.clientId,
    this.tripId,
    this.serviceRequestId,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class TripChatService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _tripSelect =
      '*, '
      'pickup_address:addresses!pickup_address_id(formatted_address), '
      'dropoff_address:addresses!dropoff_address_id(formatted_address), '
      'client:users!client_id(id, full_name, avatar_url), '
      'chat_rooms!trip_id(id, chat_messages(id, message, created_at, sender_id, is_read))';

  static const _serviceRequestSelect =
      '*, '
      'service_categories(name), '
      'address:addresses!address_id(formatted_address), '
      'client:users!client_id(id, full_name, avatar_url), '
      'chat_rooms!service_request_id(id, chat_messages(id, message, created_at, sender_id, is_read))';

  Future<List<ChatEntryData>> getChatsForDriver(
    String driverProfileId,
    String currentUserId,
  ) async {
    try {
      final res = await _client
          .from('trips')
          .select(_tripSelect)
          .eq('driver_profile_id', driverProfileId)
          .inFilter('status', [
            'awaiting_driver_confirmation',
            'scheduled',
            'started',
            'finished',
          ])
          .order('scheduled_datetime', ascending: false);
      return (res as List)
          .map(
            (r) => buildEntryFromTrip(r as Map<String, dynamic>, currentUserId),
          )
          .toList();
    } catch (e) {
      debugPrint('[TripChatService] getChatsForDriver erro: $e');
      return [];
    }
  }

  Future<int> countUnreadForProvider(String currentUserId) async {
    try {
      final res = await _client
          .from('chat_messages')
          .select('id, chat_rooms!inner(provider_id)')
          .eq('chat_rooms.provider_id', currentUserId)
          .neq('sender_id', currentUserId)
          .eq('is_read', false);
      return (res as List).length;
    } catch (e) {
      debugPrint('[TripChatService] countUnreadForProvider erro: $e');
      return 0;
    }
  }

  Future<List<ChatEntryData>> getChatsForServiceProvider(
    String providerProfileId,
    String currentUserId,
  ) async {
    try {
      final res = await _client
          .from('service_requests')
          .select(_serviceRequestSelect)
          .eq('provider_profile_id', providerProfileId)
          .inFilter('status', ['assigned', 'in_progress', 'finished'])
          .order('service_date', ascending: false);
      return (res as List)
          .map(
            (r) => buildEntryFromServiceRequest(
              r as Map<String, dynamic>,
              currentUserId,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[TripChatService] getChatsForServiceProvider erro: $e');
      return [];
    }
  }

  Future<String?> getOrCreateChatRoom({
    String? tripId,
    String? serviceRequestId,
    required String clientId,
    required String providerId,
  }) async {
    if (tripId == null && serviceRequestId == null) {
      throw ArgumentError('tripId ou serviceRequestId obrigatório');
    }
    try {
      var query = _client
          .from('chat_rooms')
          .select('id')
          .eq('provider_id', providerId);
      if (tripId != null) {
        query = query.eq('trip_id', tripId);
      } else {
        query = query.eq('service_request_id', serviceRequestId!);
      }

      final existing = await query.maybeSingle();
      if (existing != null) return existing['id'] as String;

      final insert = <String, dynamic>{
        'client_id': clientId,
        'provider_id': providerId,
      };
      if (tripId != null) insert['trip_id'] = tripId;
      if (serviceRequestId != null) {
        insert['service_request_id'] = serviceRequestId;
      }

      final res = await _client
          .from('chat_rooms')
          .insert(insert)
          .select('id')
          .single();
      return res['id'] as String;
    } catch (e) {
      debugPrint('[TripChatService] getOrCreateChatRoom erro: $e');
      return null;
    }
  }

  Future<void> sendMessage(
    String roomId,
    String senderId,
    String message,
  ) async {
    await _client.from('chat_messages').insert({
      'chat_room_id': roomId,
      'sender_id': senderId,
      'message': message,
      'message_type': 'text',
    });
  }

  Stream<List<ChatMessageData>> subscribeToMessages(String roomId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_room_id', roomId)
        .order('created_at')
        .map((rows) => rows.map(ChatMessageData.fromMap).toList());
  }

  Future<void> markMessagesRead(String roomId, String userId) async {
    try {
      await _client
          .from('chat_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('chat_room_id', roomId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[TripChatService] markMessagesRead erro: $e');
    }
  }

  // ── @visibleForTesting helpers (testáveis sem mock de Supabase) ──────────

  @visibleForTesting
  static ChatEntryData buildEntryFromTrip(
    Map<String, dynamic> row,
    String currentUserId,
  ) {
    final client = (row['client'] as Map<String, dynamic>?) ?? {};
    final pickup = (row['pickup_address'] as Map<String, dynamic>?) ?? {};
    final dropoff = (row['dropoff_address'] as Map<String, dynamic>?) ?? {};
    final rooms = (row['chat_rooms'] as List?) ?? [];

    final room = rooms.isNotEmpty ? rooms.first as Map<String, dynamic> : null;
    final roomId = room?['id'] as String?;
    final msgs = ((room?['chat_messages'] as List?) ?? [])
        .cast<Map<String, dynamic>>();

    msgs.sort(
      (a, b) => DateTime.parse(
        b['created_at'] as String,
      ).compareTo(DateTime.parse(a['created_at'] as String)),
    );

    final lastMsg = msgs.isNotEmpty ? msgs.first : null;
    final unread = msgs
        .where((m) => m['sender_id'] != currentUserId && m['is_read'] == false)
        .length;

    final origin = pickup['formatted_address'] as String? ?? '';
    final destination = dropoff['formatted_address'] as String? ?? '';
    final subtitle = origin.isNotEmpty && destination.isNotEmpty
        ? '$origin → $destination'
        : origin.isNotEmpty
        ? origin
        : destination;

    final scheduledStr = row['scheduled_datetime'] as String?;
    final title = scheduledStr != null
        ? _formatTripTitle(DateTime.parse(scheduledStr))
        : 'Corrida';

    return ChatEntryData(
      referenceId: row['id'] as String,
      isTrip: true,
      roomId: roomId,
      clientId: client['id'] as String? ?? '',
      clientName: client['full_name'] as String? ?? 'Cliente',
      clientAvatarUrl: client['avatar_url'] as String?,
      title: title,
      subtitle: subtitle,
      lastMessage: lastMsg?['message'] as String?,
      lastMessageAt: lastMsg != null
          ? DateTime.parse(lastMsg['created_at'] as String)
          : null,
      unreadCount: unread,
    );
  }

  @visibleForTesting
  static ChatEntryData buildEntryFromServiceRequest(
    Map<String, dynamic> row,
    String currentUserId,
  ) {
    final client = (row['client'] as Map<String, dynamic>?) ?? {};
    final address = (row['address'] as Map<String, dynamic>?) ?? {};
    final category = (row['service_categories'] as Map<String, dynamic>?) ?? {};
    final rooms = (row['chat_rooms'] as List?) ?? [];

    final room = rooms.isNotEmpty ? rooms.first as Map<String, dynamic> : null;
    final roomId = room?['id'] as String?;
    final msgs = ((room?['chat_messages'] as List?) ?? [])
        .cast<Map<String, dynamic>>();

    msgs.sort(
      (a, b) => DateTime.parse(
        b['created_at'] as String,
      ).compareTo(DateTime.parse(a['created_at'] as String)),
    );

    final lastMsg = msgs.isNotEmpty ? msgs.first : null;
    final unread = msgs
        .where((m) => m['sender_id'] != currentUserId && m['is_read'] == false)
        .length;

    final categoryName = category['name'] as String? ?? 'Serviço';
    final serviceDateStr = row['service_date'] as String?;
    final title = serviceDateStr != null
        ? '$categoryName · ${_formatDateShort(DateTime.parse(serviceDateStr))}'
        : categoryName;

    final subtitle = address['formatted_address'] as String? ?? '';

    return ChatEntryData(
      referenceId: row['id'] as String,
      isTrip: false,
      roomId: roomId,
      clientId: client['id'] as String? ?? '',
      clientName: client['full_name'] as String? ?? 'Cliente',
      clientAvatarUrl: client['avatar_url'] as String?,
      title: title,
      subtitle: subtitle,
      lastMessage: lastMsg?['message'] as String?,
      lastMessageAt: lastMsg != null
          ? DateTime.parse(lastMsg['created_at'] as String)
          : null,
      unreadCount: unread,
    );
  }

  static String _formatTripTitle(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return 'Corrida · $day/$month às $hour:$minute';
  }

  static String _formatDateShort(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}
