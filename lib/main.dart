import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kz_servicos_prestador/core/services/push_notification_service.dart';
import 'package:kz_servicos_prestador/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kz_servicos_prestador/core/theme/app_theme.dart';
import 'package:kz_servicos_prestador/routes/app_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;

  await Firebase.initializeApp();
  await PushNotificationService.showTripNotificationFromBackgroundMessage(
    message,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await PushNotificationService.initialize();
  } else {
    debugPrint(
      'Firebase web não inicializado: configure lib/firebase_options.dart '
      'para ativar Firebase/FCM no web.',
    );
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Inicializar Supabase (temporariamente comentado para evitar erro de API key)
  try {
    await Supabase.initialize(
      url: 'https://mtsqeomctrqfyekyzapc.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im10c3Flb21jdHJxZnlla3l6YXBjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMDYzODIsImV4cCI6MjA5NjU4MjM4Mn0.vJboLmezqk7ZjWAh3I5ZtVWXfQioAhmMQKzM_C_eaoA',
      debug: true,
    );
  } catch (e) {
    // Se falhar a inicialização do Supabase, continuar sem ele por enquanto
    debugPrint('Erro ao inicializar Supabase: $e');
  }

  runApp(const KzPrestadorApp());
}

class KzPrestadorApp extends StatelessWidget {
  const KzPrestadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KZ Serviços Prestador',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
      locale: const Locale('pt', 'BR'),
    );
  }
}
