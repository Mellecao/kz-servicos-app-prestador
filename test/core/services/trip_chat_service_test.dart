import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/services/trip_chat_service.dart';

void main() {
  group('ChatMessageData.fromMap', () {
    test('parses all fields correctly', () {
      final map = {
        'id': 'msg-1',
        'sender_id': 'user-123',
        'message': 'Olá, tudo bem?',
        'is_read': false,
        'created_at': '2026-04-15T07:50:00.000Z',
      };
      final msg = ChatMessageData.fromMap(map);
      expect(msg.id, 'msg-1');
      expect(msg.senderId, 'user-123');
      expect(msg.message, 'Olá, tudo bem?');
      expect(msg.isRead, false);
      expect(msg.sentAt, DateTime.parse('2026-04-15T07:50:00.000Z'));
    });

    test('defaults is_read to false when null', () {
      final map = {
        'id': 'msg-2',
        'sender_id': 'user-123',
        'message': 'Oi',
        'is_read': null,
        'created_at': '2026-04-15T08:00:00.000Z',
      };
      final msg = ChatMessageData.fromMap(map);
      expect(msg.isRead, false);
    });
  });

  group('TripChatService.buildEntryFromTrip', () {
    const userId = 'driver-user-123';

    test('builds entry with room and unread count', () {
      final row = {
        'id': 'trip-1',
        'scheduled_datetime': '2026-04-15T08:30:00.000Z',
        'pickup_address': {'formatted_address': 'Rua Augusta, 1200'},
        'dropoff_address': {'formatted_address': 'Aeroporto de Guarulhos'},
        'client': {'id': 'client-1', 'full_name': 'Ana Carolina'},
        'chat_rooms': [
          {
            'id': 'room-1',
            'chat_messages': [
              {
                'id': 'msg-1',
                'sender_id': 'client-1',
                'message': 'Pode confirmar o endereço?',
                'is_read': false,
                'created_at': '2026-04-15T07:50:00.000Z',
              },
            ],
          },
        ],
      };

      final entry = TripChatService.buildEntryFromTrip(row, userId);
      expect(entry.referenceId, 'trip-1');
      expect(entry.isTrip, true);
      expect(entry.roomId, 'room-1');
      expect(entry.clientId, 'client-1');
      expect(entry.clientName, 'Ana Carolina');
      expect(entry.subtitle, 'Rua Augusta, 1200 → Aeroporto de Guarulhos');
      expect(entry.lastMessage, 'Pode confirmar o endereço?');
      expect(entry.unreadCount, 1);
    });

    test('builds entry without room', () {
      final row = {
        'id': 'trip-2',
        'scheduled_datetime': '2026-04-20T10:00:00.000Z',
        'pickup_address': {'formatted_address': 'Av. Paulista'},
        'dropoff_address': {'formatted_address': 'Shopping Eldorado'},
        'client': {'id': 'client-2', 'full_name': 'Carlos'},
        'chat_rooms': [],
      };

      final entry = TripChatService.buildEntryFromTrip(row, userId);
      expect(entry.roomId, isNull);
      expect(entry.unreadCount, 0);
      expect(entry.lastMessage, isNull);
    });

    test('does not count own messages as unread', () {
      final row = {
        'id': 'trip-3',
        'scheduled_datetime': '2026-04-15T08:30:00.000Z',
        'pickup_address': {'formatted_address': 'A'},
        'dropoff_address': {'formatted_address': 'B'},
        'client': {'id': 'c-3', 'full_name': 'Test'},
        'chat_rooms': [
          {
            'id': 'room-3',
            'chat_messages': [
              {
                'id': 'm1',
                'sender_id': userId,
                'message': 'Estou a caminho',
                'is_read': false,
                'created_at': '2026-04-15T07:50:00.000Z',
              },
            ],
          },
        ],
      };

      final entry = TripChatService.buildEntryFromTrip(row, userId);
      expect(entry.unreadCount, 0);
    });

    test('title includes formatted date', () {
      final row = {
        'id': 'trip-4',
        'scheduled_datetime': '2026-04-15T08:30:00.000Z',
        'pickup_address': {'formatted_address': 'A'},
        'dropoff_address': {'formatted_address': 'B'},
        'client': {'id': 'c-4', 'full_name': 'X'},
        'chat_rooms': [],
      };

      final entry = TripChatService.buildEntryFromTrip(row, userId);
      expect(entry.title, contains('15/04'));
      expect(entry.title, contains('08:30'));
    });
  });

  group('TripChatService.buildEntryFromServiceRequest', () {
    const userId = 'provider-user-123';

    test('builds entry from service_request row', () {
      final row = {
        'id': 'sr-1',
        'service_date': '2026-04-20T09:00:00.000Z',
        'service_categories': {'name': 'Empregada doméstica'},
        'address': {'formatted_address': 'Rua das Flores, 100'},
        'client': {'id': 'client-1', 'full_name': 'Maria Silva'},
        'chat_rooms': [],
      };

      final entry = TripChatService.buildEntryFromServiceRequest(row, userId);
      expect(entry.referenceId, 'sr-1');
      expect(entry.isTrip, false);
      expect(entry.roomId, isNull);
      expect(entry.clientName, 'Maria Silva');
      expect(entry.subtitle, 'Rua das Flores, 100');
      expect(entry.title, contains('Empregada doméstica'));
      expect(entry.title, contains('20/04'));
    });

    test('builds entry with existing room', () {
      final row = {
        'id': 'sr-2',
        'service_date': '2026-04-21T14:00:00.000Z',
        'service_categories': {'name': 'Eletricista'},
        'address': {'formatted_address': 'Av. Brasil, 500'},
        'client': {'id': 'client-2', 'full_name': 'João'},
        'chat_rooms': [
          {
            'id': 'room-sr-1',
            'chat_messages': [
              {
                'id': 'msg-sr-1',
                'sender_id': 'client-2',
                'message': 'Quando chega?',
                'is_read': false,
                'created_at': '2026-04-21T13:00:00.000Z',
              },
            ],
          },
        ],
      };

      final entry = TripChatService.buildEntryFromServiceRequest(row, userId);
      expect(entry.roomId, 'room-sr-1');
      expect(entry.lastMessage, 'Quando chega?');
      expect(entry.unreadCount, 1);
    });
  });
}
