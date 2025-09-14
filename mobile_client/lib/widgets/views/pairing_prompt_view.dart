import 'package:flutter/material.dart';

class PairingPromptView extends StatelessWidget {
  final VoidCallback onPairDevice;

  const PairingPromptView({super.key, required this.onPairDevice});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.computer_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No PC Agent Paired',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Please pair a PC agent to start sending commands.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code to Pair'),
              onPressed: onPairDevice,
            ),
          ],
        ),
      ),
    );
  }
}
