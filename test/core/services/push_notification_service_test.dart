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

      expect(content?.title, 'Nova corrida disponível');
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

      expect(content?.title, 'Passageiro aceitou a corrida');
      expect(content?.body, 'João confirmou a corrida. Você já pode iniciar.');
    });

    test('ignora payloads que nao sao de corrida', () {
      final content = PushNotificationService.buildTripNotificationContent({
        'type': 'chat_message',
      });

      expect(content, isNull);
    });
  });
}
