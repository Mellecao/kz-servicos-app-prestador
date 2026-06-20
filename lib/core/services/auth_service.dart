import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kz_servicos_prestador/features/profile/data/models/mock_provider.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    debugPrint('[AuthService] Tentativa de login: $email');
    try {
      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('[AuthService] Auth response user: ${authResponse.user?.id}');

      if (authResponse.user == null) {
        debugPrint('[AuthService] ERRO: user nulo após signInWithPassword');
        return AuthResult.failure('Credenciais inválidas');
      }

      final userId = authResponse.user!.id;

      final userResponse = await _client
          .from('users')
          .select('*, provider_profiles(*, driver_profiles(*))')
          .eq('id', userId)
          .eq('role', 'provider')
          .maybeSingle();

      debugPrint('[AuthService] userResponse: $userResponse');

      if (userResponse == null) {
        await _client.auth.signOut();
        debugPrint('[AuthService] ERRO: user não encontrado como provider');
        return AuthResult.failure(
          'Acesso negado. Apenas prestadores de serviço e motoristas podem acessar.',
        );
      }

      final providerProfile =
          userResponse['provider_profiles'] as Map<String, dynamic>?;

      if (providerProfile == null) {
        await _client.auth.signOut();
        debugPrint('[AuthService] ERRO: provider_profile nulo');
        return AuthResult.failure('Perfil de prestador não encontrado.');
      }

      final status = providerProfile['status'] as String;
      debugPrint('[AuthService] Status do prestador: $status');

      if (status != 'approved') {
        await _client.auth.signOut();
        return AuthResult.failure(
          'Sua conta ainda está pendente de aprovação.',
        );
      }

      final driverProfile =
          providerProfile['driver_profiles'] as Map<String, dynamic>?;
      final isDriver = driverProfile != null;

      debugPrint('[AuthService] isDriver: $isDriver');

      final providerType = isDriver
          ? ProviderType.driver
          : ProviderType.serviceProvider;
      final providerProfileId = providerProfile['id'] as String;
      final driverProfileId = driverProfile?['id'] as String?;

      return AuthResult.success(
        providerType: providerType,
        userId: userId,
        name: userResponse['full_name'] as String,
        email: userResponse['email'] as String,
        providerProfileId: providerProfileId,
        driverProfileId: driverProfileId,
      );
    } on AuthException catch (e) {
      debugPrint(
        '[AuthService] AuthException: ${e.message} | status: ${e.statusCode}',
      );
      return AuthResult.failure(_mapAuthError(e));
    } catch (e, stack) {
      debugPrint('[AuthService] Erro inesperado: $e');
      debugPrint('[AuthService] Stack: $stack');
      return AuthResult.failure('Erro interno: ${e.toString()}');
    }
  }

  Future<AuthResult?> getCurrentUser() async {
    final user = await _restoreCurrentUser();
    debugPrint('[AuthService] getCurrentUser: ${user?.id}');
    if (user == null) return null;

    try {
      final userResponse = await _client
          .from('users')
          .select('*, provider_profiles(*, driver_profiles(*))')
          .eq('id', user.id)
          .eq('role', 'provider')
          .maybeSingle();

      if (userResponse == null) {
        await _client.auth.signOut();
        return null;
      }

      final providerProfile =
          userResponse['provider_profiles'] as Map<String, dynamic>?;

      if (providerProfile == null || providerProfile['status'] != 'approved') {
        await _client.auth.signOut();
        return null;
      }

      final driverProfile =
          providerProfile['driver_profiles'] as Map<String, dynamic>?;
      final isDriver = driverProfile != null;
      final providerType = isDriver
          ? ProviderType.driver
          : ProviderType.serviceProvider;

      return AuthResult.success(
        providerType: providerType,
        userId: user.id,
        name: userResponse['full_name'] as String,
        email: userResponse['email'] as String,
        providerProfileId: providerProfile['id'] as String,
        driverProfileId: driverProfile?['id'] as String?,
      );
    } catch (e) {
      debugPrint('[AuthService] getCurrentUser erro: $e');
      await _client.auth.signOut();
      return null;
    }
  }

  Future<User?> _restoreCurrentUser() async {
    final currentSession = _client.auth.currentSession;
    if (currentSession != null) {
      return _validUserFromSession(currentSession);
    }

    try {
      final authState = await _client.auth.onAuthStateChange
          .firstWhere(
            (state) =>
                state.event == AuthChangeEvent.initialSession ||
                state.event == AuthChangeEvent.signedIn ||
                state.event == AuthChangeEvent.signedOut,
          )
          .timeout(const Duration(seconds: 5));

      final restoredSession = authState.session ?? _client.auth.currentSession;
      if (restoredSession == null) return null;
      return _validUserFromSession(restoredSession);
    } catch (e) {
      debugPrint('[AuthService] restore session timeout/erro: $e');
      return _client.auth.currentUser;
    }
  }

  Future<User?> _validUserFromSession(Session session) async {
    if (!session.isExpired) return session.user;

    try {
      final refreshed = await _client.auth.refreshSession();
      return refreshed.session?.user ?? _client.auth.currentUser;
    } catch (e) {
      debugPrint('[AuthService] refresh session erro: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  String _mapAuthError(AuthException exception) {
    switch (exception.message) {
      case 'Invalid login credentials':
        return 'E-mail ou senha incorretos';
      case 'Email not confirmed':
        return 'E-mail não confirmado';
      case 'Too many requests':
        return 'Muitas tentativas. Tente novamente mais tarde';
      default:
        return 'Erro de autenticação: ${exception.message}';
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final ProviderType? providerType;
  final String? userId;
  final String? name;
  final String? email;
  final String? providerProfileId;
  final String? driverProfileId;

  AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.providerType,
    this.userId,
    this.name,
    this.email,
    this.providerProfileId,
    this.driverProfileId,
  });

  factory AuthResult.success({
    required ProviderType providerType,
    required String userId,
    required String name,
    required String email,
    required String providerProfileId,
    String? driverProfileId,
  }) {
    return AuthResult._(
      isSuccess: true,
      providerType: providerType,
      userId: userId,
      name: name,
      email: email,
      providerProfileId: providerProfileId,
      driverProfileId: driverProfileId,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(isSuccess: false, errorMessage: message);
  }
}
