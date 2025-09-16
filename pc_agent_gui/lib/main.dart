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

  // Provider'ları MultiProvider dışında oluşturuyoruz
  final authProvider = AuthProvider();
  final deviceProvider = DeviceProvider(
    authRepository: authRepository,
    deviceRepository: deviceRepository,
  );

  // AuthProvider'a, yöneteceği DeviceProvider'ı tanıtıyoruz
  authProvider.setDeviceProvider(deviceProvider);

  runApp(
    MultiProvider(
      providers: [
        // Önceden oluşturulmuş nesneleri .value constructor ile sağlıyoruz
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: deviceProvider),
        ChangeNotifierProvider(create: (_) => AgentConnectionProvider()),
      ],
      child: const PcAgentApp(),
    ),
  );
}
