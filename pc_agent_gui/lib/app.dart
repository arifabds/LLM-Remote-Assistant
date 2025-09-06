import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

class PcAgentApp extends StatelessWidget {
  const PcAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LLM Remote Assistant - Agent',
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}
