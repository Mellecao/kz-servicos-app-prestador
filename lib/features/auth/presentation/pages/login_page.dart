import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/features/auth/presentation/pages/auth_bottom_sheet.dart';
import 'package:kz_servicos_prestador/features/profile/data/models/mock_provider.dart';

enum AuthMode { login, register, forgotPassword }

class LoginPage extends StatelessWidget {
  final ValueChanged<ProviderType> onLoginSuccess;

  const LoginPage({super.key, required this.onLoginSuccess});

  void _showLoginSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuthBottomSheet(
        initialMode: AuthMode.login,
        onLoginSuccess: onLoginSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    final isTablet = shortestSide >= 600;
    final imageFit = isTablet ? BoxFit.contain : BoxFit.cover;
    final imageAlignment = isTablet ? Alignment.topCenter : Alignment.center;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_login_prestador.png',
            fit: imageFit,
            alignment: imageAlignment,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.95),
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.7],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom:
                MediaQuery.of(context).padding.bottom + (isTablet ? 48 : 36),
            child: FractionallySizedBox(
              widthFactor: isTablet ? 0.52 : 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _showLoginSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.highlight,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'OutfitBlack',
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
