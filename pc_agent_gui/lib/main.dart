import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/agent_connection_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/device_repository.dart';
import 'utils/window_utils.dart';

void main() async {
  await setupWindow();

  final authRepository = AuthRepository();
  final deviceRepository = DeviceRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        ChangeNotifierProxyProvider<AuthProvider, AgentConnectionProvider>(
          create: (context) => AgentConnectionProvider(
            authProvider: context.read<AuthProvider>(),
          ),
          update: (context, authProvider, previousConnectionProvider) {
            return previousConnectionProvider!
              ..updateAuthProvider(authProvider);
          },
        ),

        ChangeNotifierProxyProvider<AuthProvider, DeviceProvider>(
          create: (context) => DeviceProvider(
            authProvider: context.read<AuthProvider>(),
            authRepository: authRepository,
            deviceRepository: deviceRepository,
          ),
          update: (context, authProvider, previousDeviceProvider) {
            return previousDeviceProvider!..updateAuthProvider(authProvider);
          },
        ),
      ],
      child: const PcAgentApp(),
    ),
  );
}
