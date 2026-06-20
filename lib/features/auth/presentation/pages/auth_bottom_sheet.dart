import 'package:flutter/material.dart';
import 'package:kz_servicos_prestador/core/constants/app_colors.dart';
import 'package:kz_servicos_prestador/core/services/auth_service.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/push_notification_service.dart';
import 'package:kz_servicos_prestador/features/auth/presentation/pages/login_page.dart';
import 'package:kz_servicos_prestador/features/profile/data/models/mock_provider.dart';

class AuthBottomSheet extends StatefulWidget {
  final AuthMode initialMode;
  final ValueChanged<ProviderType> onLoginSuccess;

  const AuthBottomSheet({
    super.key,
    required this.initialMode,
    required this.onLoginSuccess,
  });

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet> {
  late AuthMode _mode;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  String? _loginError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'QuasimodoSemiBold',
        color: AppColors.textSecondary,
      ),
      prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.highlight, width: 1.5),
      ),
    );
  }

  Future<void> _submit() async {
    if (_mode == AuthMode.login) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        setState(() => _loginError = 'Preencha todos os campos');
        return;
      }

      setState(() {
        _isLoading = true;
        _loginError = null;
      });

      try {
        final result = await _authService.login(
          email: email,
          password: password,
        );

        if (mounted) {
          setState(() => _isLoading = false);

          if (result.isSuccess) {
            AuthState.login(
              providerType: result.providerType!,
              userId: result.userId!,
              name: result.name!,
              email: result.email!,
              providerProfileId: result.providerProfileId!,
              driverProfileId: result.driverProfileId,
            );
            await PushNotificationService.registerDeviceTokenForCurrentUser();
            if (!mounted) return;
            Navigator.of(context).pop();
            widget.onLoginSuccess(result.providerType!);
          } else {
            setState(() => _loginError = result.errorMessage);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loginError = 'Erro inesperado: ${e.toString()}';
          });
        }
      }
    } else if (_mode == AuthMode.forgotPassword) {
      // TODO: Implementar recuperação de senha
      setState(() => _loginError = 'Funcionalidade em desenvolvimento');
    }
  }

  String get _title => switch (_mode) {
    AuthMode.login => 'Login',
    AuthMode.forgotPassword => 'Recuperar senha',
    _ => 'Login',
  };

  String get _subtitle => switch (_mode) {
    AuthMode.login => 'Acesse sua conta como prestador',
    AuthMode.forgotPassword => 'Informe seu e-mail',
    _ => 'Acesse sua conta',
  };

  String get _primaryLabel => switch (_mode) {
    AuthMode.login => _isLoading ? 'Entrando...' : 'Login',
    AuthMode.forgotPassword => 'Enviar e-mail',
    _ => 'Login',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(_mode),
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        fontFamily: 'OutfitBlack',
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        fontFamily: 'QuasimodoSemiBold',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('E-mail', Icons.email_outlined),
              ),

              if (_mode != AuthMode.forgotPassword) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration('Senha', Icons.lock_outlined)
                      .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                ),
              ],
              if (_loginError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _loginError!,
                  style: TextStyle(
                    fontFamily: 'QuasimodoSemiBold',
                    fontSize: 13,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
              if (_mode == AuthMode.login) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _mode = AuthMode.forgotPassword),
                    child: const Text(
                      'Esqueceu a senha?',
                      style: TextStyle(
                        fontFamily: 'QuasimodoSemiBold',
                        fontSize: 13,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
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
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black87,
                          ),
                        )
                      : Text(_primaryLabel),
                ),
              ),
              if (_mode == AuthMode.forgotPassword) const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
