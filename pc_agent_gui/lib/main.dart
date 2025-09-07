import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'utils/window_utils.dart';

Future<void> main() async {
  await setupWindow();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: const PcAgentApp(),
    ),
  );
}
