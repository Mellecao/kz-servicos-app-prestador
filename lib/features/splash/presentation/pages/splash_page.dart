import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/services/auth_service.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/push_notification_service.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/features/profile/data/models/mock_provider.dart';

class SplashPage extends StatefulWidget {
  final String? redirectLocation;
  final ValueChanged<String> onFinished;

  const SplashPage({
    super.key,
    this.redirectLocation,
    required this.onFinished,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await Future.delayed(const Duration(seconds: 2));

    final result = await AuthService().getCurrentUser();
    if (!mounted) return;

    if (result == null || !result.isSuccess) {
      widget.onFinished('/login');
      return;
    }

    AuthState.login(
      providerType: result.providerType!,
      userId: result.userId!,
      name: result.name!,
      email: result.email!,
      providerProfileId: result.providerProfileId!,
      driverProfileId: result.driverProfileId,
    );
    await PushNotificationService.registerDeviceTokenForCurrentUser();

    if (result.providerType == ProviderType.serviceProvider) {
      widget.onFinished(_safeRedirect(fallback: '/provider-home'));
      return;
    }

    final driverProfileId = result.driverProfileId;
    if (driverProfileId == null) {
      widget.onFinished(_safeRedirect(fallback: '/home'));
      return;
    }

    final activeTrip = await TripService().getCurrentActiveTrip(
      driverProfileId,
    );
    if (!mounted) return;

    widget.onFinished(
      _safeRedirect(
        fallback: activeTrip == null
            ? '/home'
            : '/active-trip?tripId=${Uri.encodeComponent(activeTrip.id)}',
      ),
    );
  }

  String _safeRedirect({required String fallback}) {
    final redirect = widget.redirectLocation;
    if (redirect == null || redirect.isEmpty) return fallback;

    final uri = Uri.tryParse(redirect);
    if (uri == null || uri.path == '/splash' || uri.path == '/login') {
      return fallback;
    }
    return redirect;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Image.asset('assets/images/logo_colorida.png', width: 200),
      ),
    );
  }
}
