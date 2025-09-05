import 'package:go_router/go_router.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../screens/splash_screen.dart';

final router = GoRouter(
  initialLocation: '/splash', // Uygulama bu yoldan başlasın
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
  ],
);
