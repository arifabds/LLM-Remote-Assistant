import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/agent_connection_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/device_repository.dart';
import 'utils/window_utils.dart';

Future<void> main() async {
  await setupWindow();

  // Repository'leri burada, kökte bir kez oluşturuyoruz
  final authRepository = AuthRepository();
  final deviceRepository = DeviceRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AgentConnectionProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // Yeni DeviceProvider, AuthProvider ve repository'lere bağımlı
        ChangeNotifierProvider(
          create: (context) => DeviceProvider(
            authProvider: context.read<AuthProvider>(),
            authRepository: authRepository,
            deviceRepository: deviceRepository,
          ),
        ),
      ],
      child: const PcAgentApp(),
    ),
  );
}
