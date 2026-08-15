import 'package:flutter_test/flutter_test.dart';
import 'package:kz_servicos_prestador/core/services/push_notification_service.dart';

void main() {
  group('PushNotificationService.buildTripNotificationContent', () {
    test('monta notificacao para nova corrida', () {
      final content = PushNotificationService.buildTripNotificationContent({
        'type': 'trip_request',
        'client_name': 'Maria',
        'pickup_address': 'Av. Paulista, 1000',
        'destination_address': 'Aeroporto Congonhas',
      });

      expect(content?.title, 'Nova corrida disponível!');
      expect(
        content?.body,
        'Maria solicitou uma corrida de Av. Paulista, 1000 para Aeroporto Congonhas.',
      );
    });

    test('monta notificacao para aceite do passageiro', () {
      final content = PushNotificationService.buildTripNotificationContent({
        'type': 'passenger_accepted_trip',
        'client_name': 'João',
      });

      expect(content?.title, 'Passageiro confirmou!');
      expect(
        content?.body,
        'João confirmou a corrida. Toque para confirmar sua participação.',
      );
    });

    test('monta notificacao para awaiting_driver_confirmation', () {
      final content = PushNotificationService.buildTripNotificationContent({
        'type': 'awaiting_driver_confirmation',
        'client_name': 'João',
      });

      expect(content?.title, 'Passageiro confirmou!');
      expect(
        content?.body,
        'João confirmou a corrida. Toque para confirmar sua participação.',
      );
    });

    test('monta notificacao de nova proposta para pedido direto', () {
      final content = PushNotificationService.buildTripNotificationContent({
        'type': 'scheduled_direct_request',
        'client_name': 'Maria',
      });

      expect(content?.title, 'Nova solicitação de corrida!');
      expect(
        content?.body,
        'Maria escolheu você para uma viagem. Informe o seu valor.',
      );
    });

    test('ignora payloads que nao sao de corrida', () {
      final content = PushNotificationService.buildTripNotificationContent({
        'type': 'unknown_event',
      });

      expect(content, isNull);
    });

    test('monta notificacao normal para mensagem de chat', () {
      final content = PushNotificationService.buildTripNotificationContent({
        'type': 'chat_message',
        'sender_name': 'Maria',
        'message': 'Estou chegando na portaria',
      });

      expect(content?.title, 'Nova mensagem de Maria');
      expect(content?.body, 'Estou chegando na portaria');
    });

    test('monta notificacao para recusa do cancelamento', () {
      final content = PushNotificationService.buildTripNotificationContent({
        'type': 'trip_cancellation_rejected',
        'reason': 'O passageiro confirmou que esta no local',
      });

      expect(content?.title, 'Cancelamento recusado');
      expect(content?.body, 'Motivo: O passageiro confirmou que esta no local');
    });

    test('monta notificacao para resposta do suporte KZ', () {
      final content = PushNotificationService.buildTripNotificationContent({
        'type': 'support_message',
        'message': 'Recebemos sua solicitação e vamos verificar.',
      });

      expect(content?.title, 'Nova mensagem da KZ');
      expect(content?.body, 'Recebemos sua solicitação e vamos verificar.');
    });
  });

  group('PushNotificationService.buildOpenedMessageLocation', () {
    test('constroi redirect para solicitacao de corrida', () {
      expect(
        PushNotificationService.buildOpenedMessageLocation({
          'type': 'trip_request',
          'trip_id': 'trip-123',
        }),
        '/home?tripRequestId=trip-123',
      );
    });

    test('constroi redirect para re-check de agendamento', () {
      expect(
        PushNotificationService.buildOpenedMessageLocation({
          'type': 'recheck',
          'trip_id': 'trip-123',
        }),
        '/home?tripRequestId=trip-123',
      );
    });

    test('constroi redirect para awaiting_driver_confirmation', () {
      expect(
        PushNotificationService.buildOpenedMessageLocation({
          'type': 'awaiting_driver_confirmation',
          'trip_id': 'trip-123',
        }),
        '/home?tripRequestId=trip-123',
      );
    });

    test('ignora redirect de payload desconhecido', () {
      expect(
        PushNotificationService.buildOpenedMessageLocation({
          'type': 'unknown_event',
        }),
        isNull,
      );
    });

    test('abre lista de mensagens para notificacao de chat', () {
      expect(
        PushNotificationService.buildOpenedMessageLocation({
          'type': 'chat_message',
        }),
        '/messages',
      );
    });

    test('reabre corrida ativa quando cancelamento e recusado', () {
      expect(
        PushNotificationService.buildOpenedMessageLocation({
          'type': 'trip_cancellation_rejected',
          'trip_id': 'trip-123',
        }),
        '/home?activeTripId=trip-123',
      );
    });

    test('abre chat KZ quando suporte responde', () {
      expect(
        PushNotificationService.buildOpenedMessageLocation({
          'type': 'support_message',
          'support_conversation_id': 'conversation-123',
        }),
        '/support-chat',
      );
    });
  });

  group('PushNotificationService.isPersistentNotificationType', () {
    test('mantem corrida e re-check persistentes', () {
      expect(
        PushNotificationService.isPersistentNotificationType('trip_request'),
        isTrue,
      );
      expect(
        PushNotificationService.isPersistentNotificationType('recheck'),
        isTrue,
      );
      expect(
        PushNotificationService.isPersistentNotificationType(
          'awaiting_driver_confirmation',
        ),
        isTrue,
      );
    });

    test('mantem mensagem de chat como notificacao normal', () {
      expect(
        PushNotificationService.isPersistentNotificationType('chat_message'),
        isFalse,
      );
    });
  });

  group('PushNotificationService.buildUserDeviceRegistration', () {
    test('monta payload para registrar token android em user_devices', () {
      expect(
        PushNotificationService.buildUserDeviceRegistration(
          userId: 'user-123',
          token: 'fcm-token-abc',
        ),
        {
          'user_id': 'user-123',
          'device_token': 'fcm-token-abc',
          'platform': 'android',
          'is_active': true,
        },
      );
    });

    test(
      'monta payload para desativar tokens antigos do mesmo dispositivo',
      () {
        expect(PushNotificationService.buildInactiveUserDeviceUpdate(), {
          'is_active': false,
        });
      },
    );
  });

  group('PushNotificationService.shouldDeleteTokenBeforeRegistration', () {
    test(
      'solicita exclusao do token local quando refresh forcado esta ativo',
      () {
        expect(
          PushNotificationService.shouldDeleteTokenBeforeRegistration(
            forceRefresh: true,
          ),
          isTrue,
        );
      },
    );

    test('mantem token local quando refresh forcado esta inativo', () {
      expect(
        PushNotificationService.shouldDeleteTokenBeforeRegistration(
          forceRefresh: false,
        ),
        isFalse,
      );
    });
  });
}
