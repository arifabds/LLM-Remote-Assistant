import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    final authProvider = context.read<AuthProvider>();

    final router = GoRouter.of(context);

    final bool sessionIsValid = await _checkPersistedSession(authProvider);

    if (!mounted) return;

    if (sessionIsValid) {
      router.go('/home');
    } else {
      await authProvider.logout();
      router.go('/auth');
    }
  }

  Future<bool> _checkPersistedSession(AuthProvider authProvider) async {
    final bool hasToken = await authProvider.tryAutoLogin();

    if (!hasToken || authProvider.token == null) {
      return false;
    }

    try {
      final bool isExpired = JwtDecoder.isExpired(authProvider.token!);
      return !isExpired;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
