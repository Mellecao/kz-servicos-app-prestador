import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_brand.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/widgets/brand_backdrop.dart';
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
    final isTablet = size.shortestSide >= 600;
    final logoWidth = isTablet ? 360.0 : size.width * 0.7;

    return Scaffold(
      backgroundColor: AppColors.brandDark,
      body: BrandBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        AppBrand.logoWhite,
                        width: logoWidth,
                        semanticLabel: AppBrand.name,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Área do prestador',
                        style: TextStyle(
                          fontFamily: 'QuasimodoSemiBold',
                          fontSize: 14,
                          color: AppColors.highlightLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: isTablet ? 48 : 36),
                child: FractionallySizedBox(
                  widthFactor: isTablet ? 0.52 : 0.8,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _showLoginSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.highlight,
                        foregroundColor: AppColors.onHighlight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'OutfitBlack',
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Entrar'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
