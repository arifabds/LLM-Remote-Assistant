import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'services/agent_service.dart';

class PcAgentApp extends StatefulWidget {
  const PcAgentApp({super.key});

  @override
  State<PcAgentApp> createState() => _PcAgentAppState();
}

class _PcAgentAppState extends State<PcAgentApp> {
  @override
  void dispose() {
    agentService.dispose();
    super.dispose();
  }

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
