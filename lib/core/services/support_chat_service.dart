import 'package:supabase_flutter/supabase_flutter.dart';

class SupportConversationData {
  final String id;
  final String providerUserId;
  final int unreadProviderCount;

  const SupportConversationData({
    required this.id,
    required this.providerUserId,
    required this.unreadProviderCount,
  });

  factory SupportConversationData.fromMap(Map<String, dynamic> map) {
    return SupportConversationData(
      id: map['id'] as String,
      providerUserId: map['provider_user_id'] as String,
      unreadProviderCount: map['unread_provider_count'] as int? ?? 0,
    );
  }
}

class SupportMessageData {
  final String id;
  final String conversationId;
  final String senderId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const SupportMessageData({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory SupportMessageData.fromMap(Map<String, dynamic> map) {
    return SupportMessageData(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      message: map['message'] as String,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class SupportChatService {
  final SupabaseClient _client;

  SupportChatService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static Map<String, dynamic> buildConversationPayload(String providerUserId) {
    return {'provider_user_id': providerUserId};
  }

  static Map<String, dynamic> buildMessagePayload({
    required String conversationId,
    required String senderId,
    required String message,
  }) {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message': message.trim(),
    };
  }

  Future<SupportConversationData> getOrCreateConversation(
    String providerUserId,
  ) async {
    final existing = await _findConversation(providerUserId);
    if (existing != null) return existing;

    try {
      final row = await _client
          .from('support_conversations')
          .insert(buildConversationPayload(providerUserId))
          .select()
          .single();
      return SupportConversationData.fromMap(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final concurrent = await _findConversation(providerUserId);
      if (concurrent == null) rethrow;
      return concurrent;
    }
  }

  Future<SupportConversationData?> _findConversation(
    String providerUserId,
  ) async {
    final row = await _client
        .from('support_conversations')
        .select()
        .eq('provider_user_id', providerUserId)
        .maybeSingle();
    if (row == null) return null;
    return SupportConversationData.fromMap(row);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String message,
  }) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty || cleanMessage.length > 4000) {
      throw ArgumentError('A mensagem deve ter entre 1 e 4000 caracteres.');
    }
    await _client
        .from('support_messages')
        .insert(
          buildMessagePayload(
            conversationId: conversationId,
            senderId: senderId,
            message: cleanMessage,
          ),
        );
  }

  Stream<List<SupportMessageData>> subscribeToMessages(String conversationId) {
    return _client
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) {
          final messages = rows.map(SupportMessageData.fromMap).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return messages;
        });
  }

  Future<void> markMessagesRead({
    required String conversationId,
    required String readerId,
  }) async {
    await _client
        .from('support_messages')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('conversation_id', conversationId)
        .neq('sender_id', readerId)
        .eq('is_read', false);
  }
}
