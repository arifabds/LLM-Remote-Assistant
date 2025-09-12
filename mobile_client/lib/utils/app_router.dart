import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/devices_screen.dart';

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  late final GoRouter router = GoRouter(
    refreshListenable: authProvider,

    debugLogDiagnostics: true,
    initialLocation: '/splash',

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/qr-scanner',
        builder: (context, state) => const QRScannerScreen(),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
    ],

    redirect: (BuildContext context, GoRouterState state) {
      final bool isLoading = authProvider.isLoading;
      final bool loggedIn = authProvider.isAuthenticated;
      final bool onAuthRoute = state.matchedLocation == '/auth';
      final bool onSplashRoute = state.matchedLocation == '/splash';

      if (isLoading && !onSplashRoute) {
        return '/splash';
      }

      if (!isLoading) {
        if (!loggedIn && !onAuthRoute && !onSplashRoute) {
          return '/auth';
        }
        if (loggedIn && (onAuthRoute || onSplashRoute)) {
          return '/home';
        }
      }

      return null;
    },
  );
}
