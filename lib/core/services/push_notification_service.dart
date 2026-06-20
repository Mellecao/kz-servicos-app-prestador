import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class TripNotificationContent {
  final String title;
  final String body;

  const TripNotificationContent({required this.title, required this.body});
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _tripChannel =
      AndroidNotificationChannel(
        'trip_notifications',
        'Corridas',
        description: 'Notificações de novas corridas e confirmações.',
        importance: Importance.high,
      );

  static bool _localInitialized = false;

  static Future<void> initialize() async {
    await _initializeLocalNotifications();
    await requestNotificationPermission();

    FirebaseMessaging.onMessage.listen(showTripNotificationFromMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
  }

  static Future<void> requestNotificationPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  static Future<void> registerDeviceTokenForCurrentUser() async {
    if (!AuthState.isAuthenticated) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _saveToken(token);

      _messaging.onTokenRefresh.listen((newToken) {
        unawaited(_saveToken(newToken));
      });
    } catch (e) {
      debugPrint('[KZ-FCM] token registration error: $e');
    }
  }

  static Future<void> showTripNotificationFromMessage(
    RemoteMessage message,
  ) async {
    final content = message.notification == null
        ? buildTripNotificationContent(message.data)
        : _contentFromNotificationPayload(message);
    if (content == null) return;

    final type = '${message.data['type'] ?? message.data['event'] ?? ''}';
    final persistent = _isPersistent(type);

    await _showLocalNotification(
      content: content,
      payload: jsonEncode(message.data),
      persistent: persistent,
    );
  }

  static Future<void> showTripNotificationFromBackgroundMessage(
    RemoteMessage message,
  ) async {
    if (message.notification != null) return;
    await showTripNotificationFromMessage(message);
  }

  static bool _isPersistent(String type) {
    return type == 'trip_request' ||
        type == 'new_trip' ||
        type == 'new_trip_request' ||
        type == 'recheck';
  }

  static TripNotificationContent? buildTripNotificationContent(
    Map<String, dynamic> data,
  ) {
    final type = '${data['type'] ?? data['event'] ?? ''}';
    final clientName = _value(data, ['client_name', 'clientName', 'passenger']);
    final pickup = _value(data, ['pickup_address', 'pickupAddress', 'origin']);
    final destination = _value(data, [
      'destination_address',
      'destinationAddress',
      'destination',
    ]);

    return switch (type) {
      'trip_request' ||
      'new_trip' ||
      'new_trip_request' => TripNotificationContent(
        title: 'Nova corrida disponível!',
        body: pickup.isNotEmpty && destination.isNotEmpty
            ? '${clientName.isNotEmpty ? clientName : 'Um passageiro'} solicitou uma corrida de $pickup para $destination.'
            : '${clientName.isNotEmpty ? clientName : 'Um passageiro'} solicitou uma nova corrida.',
      ),
      'recheck' ||
      'passenger_accepted_trip' ||
      'client_accepted_trip' ||
      'trip_accepted_by_client' => TripNotificationContent(
        title: 'Passageiro confirmou!',
        body:
            '${clientName.isNotEmpty ? clientName : 'O passageiro'} confirmou a corrida. Toque para confirmar sua participação.',
      ),
      'trip_scheduled_driver' => const TripNotificationContent(
        title: 'Viagem agendada!',
        body: 'A viagem foi confirmada e agendada.',
      ),
      'trip_started_driver' => const TripNotificationContent(
        title: 'Viagem em andamento',
        body: 'A viagem está em andamento.',
      ),
      'trip_finished_driver' => const TripNotificationContent(
        title: 'Corrida concluída!',
        body: 'A corrida foi finalizada com sucesso.',
      ),
      'trip_cancelled_driver' => const TripNotificationContent(
        title: 'Corrida cancelada',
        body: 'A corrida foi cancelada.',
      ),
      'service_assigned' => const TripNotificationContent(
        title: 'Novo serviço!',
        body: 'Um serviço foi atribuído a você.',
      ),
      'service_cancelled' => const TripNotificationContent(
        title: 'Serviço cancelado',
        body: 'O serviço foi cancelado.',
      ),
      _ => null,
    };
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localInitialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(settings: initializationSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_tripChannel);

    _localInitialized = true;
  }

  static Future<void> _showLocalNotification({
    required TripNotificationContent content,
    String? payload,
    bool persistent = false,
  }) async {
    await _initializeLocalNotifications();

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: content.title,
      body: content.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _tripChannel.id,
          _tripChannel.name,
          channelDescription: _tripChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.status,
          ongoing: persistent,
          autoCancel: !persistent,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  static TripNotificationContent? _contentFromNotificationPayload(
    RemoteMessage message,
  ) {
    final notification = message.notification;
    if (notification == null) return null;

    final fallback = buildTripNotificationContent(message.data);
    return TripNotificationContent(
      title: notification.title ?? fallback?.title ?? 'KZ Serviços',
      body: notification.body ?? fallback?.body ?? 'Você tem uma atualização.',
    );
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('[KZ-FCM] notification opened: ${message.data}');
  }

  static Future<void> _saveToken(String token) async {
    final userId = AuthState.userId;
    if (userId == null) return;

    final update = {
      'fcm_token': token,
      'fcm_token_updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await Supabase.instance.client
          .from('users')
          .update(update)
          .eq('id', userId);
    } catch (e) {
      debugPrint('[KZ-FCM] users token update ignored: $e');
    }

    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null) return;

    try {
      await Supabase.instance.client
          .from('driver_profiles')
          .update(update)
          .eq('id', driverProfileId);
    } catch (e) {
      debugPrint('[KZ-FCM] driver token update ignored: $e');
    }
  }

  static String _value(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }
}
