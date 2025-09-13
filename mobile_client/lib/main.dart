import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/command_provider.dart';
import 'providers/device_provider.dart';
import 'utils/app_router.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),

        ChangeNotifierProxyProvider2<
          AuthProvider,
          DeviceProvider,
          CommandProvider
        >(
          create: (context) => CommandProvider(
            authProvider: context.read<AuthProvider>(),
            deviceProvider: context.read<DeviceProvider>(),
          ),

          update: (_, auth, device, previous) {
            previous!.updateDependencies(auth, device);
            previous.onAuthError = () => auth.logout();
            return previous;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _router = AppRouter(authProvider).router;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LLM Remote Assistant',
      theme: ThemeData.dark(useMaterial3: true),
      routerConfig: _router,
    );
  }
}
