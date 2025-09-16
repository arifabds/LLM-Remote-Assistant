import 'package:flutter/foundation.dart';
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
  final Stopwatch _logStopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-INIT] initState called.',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-POSTFRAME] Post frame callback triggered. Calling _initialize.',
      );
      _initialize();
    });
  }

  Future<void> _initialize() async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-INIT-START] _initialize function started.',
    );
    final authProvider = context.read<AuthProvider>();
    final router = GoRouter.of(context);

    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-SESSION-CHECK-START] Calling _checkPersistedSession...',
    );
    final bool sessionIsValid = await _checkPersistedSession(authProvider);
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-SESSION-CHECK-END] _checkPersistedSession returned: $sessionIsValid.',
    );

    if (!mounted) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-NOT-MOUNTED] Component is no longer mounted. Aborting navigation.',
      );
      return;
    }

    final String targetRoute;
    if (sessionIsValid) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-DECISION-VALID] Session is valid. Target route: /home.',
      );
      targetRoute = '/home';
    } else {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-DECISION-INVALID] Session is invalid or expired. Calling logout and setting target route to /auth.',
      );
      await authProvider.logout();
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-DECISION-LOGOUT-COMPLETE] authProvider.logout() completed.',
      );
      targetRoute = '/auth';
    }

    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-NAVIGATE] Navigating to route: "$targetRoute".',
    );
    router.go(targetRoute);
  }

  Future<bool> _checkPersistedSession(AuthProvider authProvider) async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SESSION-START] _checkPersistedSession started. Calling tryAutoLogin.',
    );
    final bool hasToken = await authProvider.tryAutoLogin();

    if (!hasToken || authProvider.token == null) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SESSION-NO-TOKEN] tryAutoLogin returned false or token is null. Session is invalid.',
      );
      return false;
    }
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SESSION-HAS-TOKEN] tryAutoLogin returned true. Token found. Checking expiration.',
    );

    try {
      final bool isExpired = JwtDecoder.isExpired(authProvider.token!);
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SESSION-EXP-CHECK] Token expiration check successful. Is expired: $isExpired.',
      );
      return !isExpired;
    } catch (e) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SESSION-DECODE-ERROR] Error decoding JWT: $e. Session is invalid.',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-BUILD] Build method called.',
    );
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  @override
  void dispose() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-SPLASH-DISPOSE] Dispose method called.',
    );
    super.dispose();
  }
}
