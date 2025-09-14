import 'package:flutter/material.dart';

class AgentOfflineView extends StatelessWidget {
  final VoidCallback onRefresh;

  const AgentOfflineView({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.signal_wifi_off_outlined,
              size: 80,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 20),
            const Text(
              'Agent is Offline',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Please make sure your paired PC agent is running and connected to the internet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextButton(
              onPressed: onRefresh,
              child: const Text('Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }
}
