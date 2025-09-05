import 'package:flutter/material.dart';
import 'utils/app_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/command_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, CommandProvider>(
          create: (_) => CommandProvider(),
          update: (_, auth, previousCommandProvider) =>
              previousCommandProvider!..update(auth),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LLM Remote Assistant',
      theme: ThemeData.dark(useMaterial3: true),
      routerConfig: router,
    );
  }
}
