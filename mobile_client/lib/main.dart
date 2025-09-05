import 'package:flutter/material.dart';
import 'utils/app_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
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
