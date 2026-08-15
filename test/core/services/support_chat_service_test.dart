import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/services/support_chat_service.dart';

void main() {
  group('SupportChatService payloads', () {
    test('monta conversa persistente para o usuario prestador', () {
      expect(SupportChatService.buildConversationPayload('provider-123'), {
        'provider_user_id': 'provider-123',
      });
    });

    test('normaliza mensagem antes do insert', () {
      expect(
        SupportChatService.buildMessagePayload(
          conversationId: 'conversation-123',
          senderId: 'provider-123',
          message: '  Preciso de ajuda  ',
        ),
        {
          'conversation_id': 'conversation-123',
          'sender_id': 'provider-123',
          'message': 'Preciso de ajuda',
        },
      );
    });
  });

  test('converte mensagem recebida do Supabase', () {
    final message = SupportMessageData.fromMap({
      'id': 'message-123',
      'conversation_id': 'conversation-123',
      'sender_id': 'admin-123',
      'message': 'Como podemos ajudar?',
      'is_read': false,
      'created_at': '2026-07-14T15:30:00Z',
    });

    expect(message.id, 'message-123');
    expect(message.senderId, 'admin-123');
    expect(message.isRead, isFalse);
    expect(message.createdAt.toUtc(), DateTime.utc(2026, 7, 14, 15, 30));
  });
}
