import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kz_servicos_prestador/core/models/trip_data.dart';
import 'package:kz_servicos_prestador/core/services/auth_service.dart';
import 'package:kz_servicos_prestador/core/services/auth_state.dart';
import 'package:kz_servicos_prestador/core/services/trip_service.dart';
import 'package:kz_servicos_prestador/core/widgets/circle_button.dart';
import 'package:kz_servicos_prestador/features/auth/presentation/pages/login_page.dart';
import 'package:kz_servicos_prestador/features/benefits/presentation/pages/benefits_page.dart';
import 'package:kz_servicos_prestador/core/services/trip_chat_service.dart';
import 'package:kz_servicos_prestador/features/chat/presentation/pages/chat_page.dart';
import 'package:kz_servicos_prestador/features/chat/presentation/pages/messages_page.dart';
import 'package:kz_servicos_prestador/features/earnings/presentation/pages/earnings_page.dart';
import 'package:kz_servicos_prestador/features/home/presentation/pages/home_page.dart';
import 'package:kz_servicos_prestador/features/other_services/presentation/pages/provider_earnings_page.dart';
import 'package:kz_servicos_prestador/features/other_services/presentation/pages/provider_profile_page.dart';
import 'package:kz_servicos_prestador/features/other_services/presentation/pages/service_requests_page.dart';
import 'package:kz_servicos_prestador/features/profile/data/models/mock_provider.dart';
import 'package:kz_servicos_prestador/features/profile/presentation/pages/profile_page.dart';
import 'package:kz_servicos_prestador/features/profile/presentation/pages/security_settings_page.dart';
import 'package:kz_servicos_prestador/features/splash/presentation/pages/splash_page.dart';
import 'package:kz_servicos_prestador/features/trip/data/models/active_trip_data.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/pages/active_trip_loader_page.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/pages/active_trip_page.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/pages/trip_history_detail_page.dart';
import 'package:kz_servicos_prestador/features/trip/presentation/pages/trip_history_page.dart';
import 'package:kz_servicos_prestador/features/schedules/presentation/pages/schedules_page.dart';
import 'package:kz_servicos_prestador/features/schedules/presentation/pages/schedule_detail_page.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: _authGuard,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => SplashPage(
          redirectLocation: state.uri.queryParameters['redirect'],
          onFinished: (location) => context.go(location),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          onLoginSuccess: (type) async {
            if (type == ProviderType.serviceProvider) {
              context.go('/provider-home');
            } else {
              final location = await _driverStartLocation();
              if (context.mounted) context.go(location);
            }
          },
        ),
      ),
      // Driver routes
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            HomePage(onNavTap: (i) => _handleNavTap(context, state, i)),
      ),
      GoRoute(
        path: '/trip-history',
        builder: (context, state) =>
            _withActiveTripBack(context, state, const TripHistoryPage()),
      ),
      GoRoute(
        path: '/earnings',
        builder: (context, state) => _withActiveTripBack(
          context,
          state,
          EarningsPage(onNavTap: (i) => _handleNavTap(context, state, i)),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => _withActiveTripBack(
          context,
          state,
          ProfilePage(onNavTap: (i) => _handleNavTap(context, state, i)),
        ),
      ),
      GoRoute(
        path: '/benefits',
        builder: (context, state) =>
            _withActiveTripBack(context, state, const BenefitsPage()),
      ),
      GoRoute(
        path: '/active-trip',
        builder: (context, state) {
          final trip = state.extra is ActiveTripData
              ? state.extra as ActiveTripData
              : null;
          if (trip != null) return ActiveTripPage(trip: trip);
          return ActiveTripLoaderPage(
            tripId: state.uri.queryParameters['tripId'],
          );
        },
      ),
      GoRoute(
        path: '/trip-history-detail',
        builder: (context, state) {
          final trip = state.extra as TripData;
          return TripHistoryDetailPage(trip: trip);
        },
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) =>
            _withActiveTripBack(context, state, const MessagesPage()),
      ),
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) {
          final args = state.extra as ChatPageArgs;
          return ChatPage(args: args);
        },
      ),
      GoRoute(
        path: '/security-settings',
        builder: (context, state) => const SecuritySettingsPage(),
      ),
      GoRoute(
        path: '/schedules',
        builder: (context, state) => _withActiveTripBack(
          context,
          state,
          SchedulesPage(onNavTap: (i) => _handleNavTap(context, state, i)),
        ),
      ),
      GoRoute(
        path: '/schedule-detail',
        builder: (context, state) {
          final trip = state.extra as TripData;
          final fromHome = state.uri.queryParameters['fromHome'] == 'true';
          return ScheduleDetailPage(trip: trip, fromHome: fromHome);
        },
      ),
      // Service provider routes
      GoRoute(
        path: '/provider-home',
        builder: (context, state) => ServiceRequestsPage(
          onNavTap: (i) => _handleProviderNavTap(context, i),
        ),
      ),
      GoRoute(
        path: '/provider-earnings',
        builder: (context, state) => ProviderEarningsPage(
          onNavTap: (i) => _handleProviderNavTap(context, i),
        ),
      ),
      GoRoute(
        path: '/provider-profile',
        builder: (context, state) => ProviderProfilePage(
          onNavTap: (i) => _handleProviderNavTap(context, i),
        ),
      ),
    ],
  );

  static String? _authGuard(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final publicRoutes = ['/splash', '/login'];
    if (publicRoutes.contains(path)) return null;
    if (!AuthState.isAuthenticated) {
      final redirect = Uri.encodeComponent(state.uri.toString());
      return '/splash?redirect=$redirect';
    }
    final activeTripRedirect = activeTripHomeRedirect(state.uri);
    if (activeTripRedirect != null) return activeTripRedirect;
    return null;
  }

  static String? activeTripHomeRedirect(Uri uri) {
    if (uri.path != '/home') return null;

    final activeTripId = uri.queryParameters['returnToActiveTripId'];
    if (activeTripId == null || activeTripId.isEmpty) return null;

    return '/active-trip?tripId=${Uri.encodeComponent(activeTripId)}';
  }

  static void _handleNavTap(
    BuildContext context,
    GoRouterState state,
    int index,
  ) {
    final routes = ['/home', '/schedules', '/earnings', '/profile'];
    final activeTripId = state.uri.queryParameters['returnToActiveTripId'];
    if (activeTripId == null) {
      context.go(routes[index]);
      return;
    }
    context.pushReplacement(
      '${routes[index]}?returnToActiveTripId=${Uri.encodeComponent(activeTripId)}',
    );
  }

  static Widget _withActiveTripBack(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    final activeTripId = state.uri.queryParameters['returnToActiveTripId'];
    if (activeTripId == null) return child;

    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: CircleButton(
            icon: Icons.arrow_back,
            onTap: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go(
                '/active-trip?tripId=${Uri.encodeComponent(activeTripId)}',
              );
            },
          ),
        ),
      ],
    );
  }

  static void _handleProviderNavTap(BuildContext context, int index) {
    const routes = [
      '/provider-home',
      '/provider-earnings',
      '/provider-profile',
    ];
    context.go(routes[index]);
  }

  static Future<String> _driverStartLocation() async {
    final driverProfileId = AuthState.driverProfileId;
    if (driverProfileId == null) return '/home';

    final activeTrip = await TripService().getCurrentActiveTrip(
      driverProfileId,
    );
    if (activeTrip == null) return '/home';

    return '/active-trip?tripId=${Uri.encodeComponent(activeTrip.id)}';
  }

  static Future<void> logout(BuildContext context) async {
    AuthState.logout();
    await AuthService().logout();
    if (context.mounted) context.go('/login');
  }
}
