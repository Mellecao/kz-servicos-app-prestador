import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:kz_servicos_prestador/core/constants/app_brand.dart';
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

  static const String tripChannelId = 'trip_alerts_v3';
  static const String messageChannelId = 'driver_messages_v1';
  static const AndroidNotificationChannel _tripChannel =
      AndroidNotificationChannel(
        tripChannelId,
        'Solicitações de viagem',
        description: 'Alertas sonoros de novas solicitações de viagem.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('trip_notification'),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
  static const AndroidNotificationChannel _messageChannel =
      AndroidNotificationChannel(
        messageChannelId,
        'Mensagens',
        description: 'Mensagens de clientes e do suporte.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  static bool _localInitialized = false;
  static void Function(String location)? _onOpenLocation;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static final StreamController<Map<String, dynamic>> _foregroundEvents =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get foregroundEvents =>
      _foregroundEvents.stream;

  static Future<void> initialize({
    required void Function(String location) onOpenLocation,
  }) async {
    _onOpenLocation = onOpenLocation;
    await _initializeLocalNotifications();
    await requestNotificationPermission();
    await _requestAndroidNotificationPermission();

    FirebaseMessaging.onMessage.listen(showTripNotificationFromMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleOpenedMessage(message, onOpenLocation);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleOpenedMessage(initialMessage, onOpenLocation);
      });
    }
  }

  static Future<void> requestNotificationPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  static Future<void> _requestAndroidNotificationPermission() async {
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestFullScreenIntentPermission();
  }

  static Future<void> registerDeviceTokenForCurrentUser({
    bool forceRefresh = false,
  }) async {
    if (!AuthState.isAuthenticated) return;

    try {
      if (shouldDeleteTokenBeforeRegistration(forceRefresh: forceRefresh)) {
        await _messaging.deleteToken();
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _saveToken(token);
      debugPrint('[KZ-FCM] token registered: ${_tokenPrefix(token)}');

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        unawaited(_saveToken(newToken));
      });
    } catch (e) {
      debugPrint('[KZ-FCM] token registration error: $e');
    }
  }

  static bool shouldDeleteTokenBeforeRegistration({
    required bool forceRefresh,
  }) {
    return forceRefresh;
  }

  static Future<void> showTripNotificationFromMessage(
    RemoteMessage message,
  ) async {
    _foregroundEvents.add(message.data);
    final content = message.notification == null
        ? buildTripNotificationContent(message.data)
        : _contentFromNotificationPayload(message);
    if (content == null) return;

    final type = '${message.data['type'] ?? message.data['event'] ?? ''}';
    final persistent = isPersistentNotificationType(type);

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

  static bool isPersistentNotificationType(String type) {
    return type == 'trip_request' ||
        type == 'new_trip' ||
        type == 'new_trip_request' ||
        type == 'recheck' ||
        type == 'awaiting_driver_confirmation' ||
        type == 'passenger_accepted_trip' ||
        type == 'client_accepted_trip' ||
        type == 'trip_accepted_by_client' ||
        type == 'scheduled_direct_request';
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
    final cancellationReviewReason = _value(data, ['reason', 'review_reason']);

    return switch (type) {
      'trip_request' ||
      'new_trip' ||
      'new_trip_request' => TripNotificationContent(
        title: 'Nova viagem disponível!',
        body: pickup.isNotEmpty && destination.isNotEmpty
            ? '${clientName.isNotEmpty ? clientName : 'Um passageiro'} solicitou uma viagem de $pickup para $destination.'
            : '${clientName.isNotEmpty ? clientName : 'Um passageiro'} solicitou uma nova viagem.',
      ),
      'scheduled_direct_request' => TripNotificationContent(
        title: 'Nova solicitação de viagem!',
        body:
            '${clientName.isNotEmpty ? clientName : 'Um cliente'} escolheu o seu perfil para uma viagem. Indique o seu valor.',
      ),
      'recheck' ||
      'awaiting_driver_confirmation' ||
      'passenger_accepted_trip' ||
      'client_accepted_trip' ||
      'trip_accepted_by_client' => TripNotificationContent(
        title: 'Passageiro confirmou!',
        body:
            '${clientName.isNotEmpty ? clientName : 'O passageiro'} confirmou a viagem. Toque para confirmar a sua participação.',
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
        title: 'Viagem concluída!',
        body: 'A viagem foi terminada com sucesso.',
      ),
      'trip_cancelled_driver' => const TripNotificationContent(
        title: 'Viagem cancelada',
        body: 'A viagem foi cancelada.',
      ),
      'trip_cancellation_rejected' => TripNotificationContent(
        title: 'Cancelamento recusado',
        body: cancellationReviewReason.isNotEmpty
            ? 'Motivo: $cancellationReviewReason'
            : 'A viagem continua ativa.',
      ),
      'service_assigned' => const TripNotificationContent(
        title: 'Novo serviço!',
        body: 'Foi-lhe atribuído um serviço.',
      ),
      'service_cancelled' => const TripNotificationContent(
        title: 'Serviço cancelado',
        body: 'O serviço foi cancelado.',
      ),
      'chat_message' => TripNotificationContent(
        title:
            'Nova mensagem de ${_value(data, ['sender_name', 'senderName', 'client_name', 'clientName']).isNotEmpty ? _value(data, ['sender_name', 'senderName', 'client_name', 'clientName']) : 'Suporte'}',
        body: _value(data, ['message', 'body', 'preview']).isNotEmpty
            ? _value(data, ['message', 'body', 'preview'])
            : 'Recebeu uma nova mensagem.',
      ),
      'support_message' => TripNotificationContent(
        title: 'Nova mensagem do suporte',
        body: _value(data, ['message', 'body', 'preview']).isNotEmpty
            ? _value(data, ['message', 'body', 'preview'])
            : 'Recebeu uma nova mensagem.',
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

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_tripChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_messageChannel);

    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleLocalNotificationResponse(launchResponse);
      });
    }

    _localInitialized = true;
  }

  static void _handleLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final onOpenLocation = _onOpenLocation;
    if (payload == null || payload.isEmpty || onOpenLocation == null) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = decoded.map((key, value) => MapEntry(key.toString(), value));
      final location = buildOpenedMessageLocation(data);
      if (location != null) onOpenLocation(location);
    } catch (error) {
      debugPrint('[KZ-FCM] local notification payload invalido: $error');
    }
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
          persistent ? _tripChannel.id : _messageChannel.id,
          persistent ? _tripChannel.name : _messageChannel.name,
          channelDescription: persistent
              ? _tripChannel.description
              : _messageChannel.description,
          importance: persistent ? Importance.max : Importance.high,
          priority: persistent ? Priority.max : Priority.high,
          sound: persistent
              ? const RawResourceAndroidNotificationSound('trip_notification')
              : null,
          playSound: true,
          enableVibration: true,
          vibrationPattern: persistent
              ? Int64List.fromList([0, 800, 300, 800, 300, 800])
              : null,
          fullScreenIntent: persistent,
          additionalFlags: persistent ? Int32List.fromList(<int>[4, 32]) : null,
          audioAttributesUsage: persistent
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          category: AndroidNotificationCategory.call,
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
      title: notification.title ?? fallback?.title ?? AppBrand.name,
      body: notification.body ?? fallback?.body ?? 'Tem uma atualização.',
    );
  }

  static String? buildOpenedMessageLocation(Map<String, dynamic> data) {
    final tripType = '${data['trip_type'] ?? ''}';
    final tripId = '${data['trip_id'] ?? ''}'.trim();
    if (tripType == 'flash' && tripId.isNotEmpty) {
      final route = '${data['route'] ?? '/flash/incoming'}';
      return '$route?tripId=${Uri.encodeComponent(tripId)}';
    }
    if (tripType == 'scheduled_choose_driver' && tripId.isNotEmpty) {
      return '/schedules?tripId=${Uri.encodeComponent(tripId)}';
    }
    final type = '${data['type'] ?? data['event'] ?? ''}';
    if ((type == 'scheduled_direct_request' ||
            type == 'scheduled_direct_confirmed') &&
        tripId.isNotEmpty) {
      return '/schedules?tripId=${Uri.encodeComponent(tripId)}';
    }
    if ((type == 'trip_request' ||
            type == 'new_trip_request' ||
            type == 'recheck' ||
            type == 'awaiting_driver_confirmation' ||
            type == 'passenger_accepted_trip' ||
            type == 'client_accepted_trip' ||
            type == 'trip_accepted_by_client') &&
        tripId.isNotEmpty) {
      return '/home?tripRequestId=${Uri.encodeComponent(tripId)}';
    }
    if (type == 'trip_cancellation_rejected' && tripId.isNotEmpty) {
      return '/home?activeTripId=${Uri.encodeComponent(tripId)}';
    }
    if (type == 'support_message') return '/support-chat';
    if (type == 'chat_message') return '/messages';
    return null;
  }

  static void _handleOpenedMessage(
    RemoteMessage message,
    void Function(String location) onOpenLocation,
  ) {
    debugPrint('[KZ-FCM] notification opened: ${message.data}');
    final location = buildOpenedMessageLocation(message.data);
    if (location != null) {
      onOpenLocation(location);
    }
  }

  static Map<String, dynamic> buildUserDeviceRegistration({
    required String userId,
    required String token,
    String? platform,
  }) {
    return {
      'user_id': userId,
      'device_token': token,
      'platform': platform ?? _currentPlatformType(),
      'is_active': true,
    };
  }

  static Map<String, dynamic> buildInactiveUserDeviceUpdate() {
    return {'is_active': false};
  }

  static Future<void> _saveToken(String token) async {
    final userId = AuthState.userId;
    if (userId == null) return;

    await _saveUserDeviceToken(userId: userId, token: token);

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

  static Future<void> _saveUserDeviceToken({
    required String userId,
    required String token,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final platform = _currentPlatformType();
    final registration = {
      ...buildUserDeviceRegistration(
        userId: userId,
        token: token,
        platform: platform,
      ),
      'last_used_at': now,
    };

    try {
      await Supabase.instance.client
          .from('user_devices')
          .update(buildInactiveUserDeviceUpdate())
          .eq('user_id', userId)
          .eq('platform', platform)
          .neq('device_token', token);

      await Supabase.instance.client
          .from('user_devices')
          .upsert(registration, onConflict: 'user_id,device_token');
    } catch (e) {
      debugPrint('[KZ-FCM] user_devices token upsert ignored: $e');
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

  static String _currentPlatformType() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'web',
    };
  }

  static String _tokenPrefix(String token) {
    return token.length <= 12 ? token : token.substring(0, 12);
  }
}
