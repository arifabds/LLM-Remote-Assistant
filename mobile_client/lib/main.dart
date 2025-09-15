import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/command_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/device_provider.dart';
import 'repositories/command_repository.dart';
import 'utils/app_router.dart';

void main() {
  final commandRepository = CommandRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),

        ChangeNotifierProvider(
          create: (context) => ConnectionProvider(
            authProvider: context.read<AuthProvider>(),
            commandRepository: commandRepository,
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => CommandProvider(
            authProvider: context.read<AuthProvider>(),
            connectionProvider: context.read<ConnectionProvider>(),
            commandRepository: commandRepository,
          ),
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
