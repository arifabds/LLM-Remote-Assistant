import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _scannedQrCodeValue;

  Future<void> _navigateToScanner() async {
    final result = await context.push<String>('/qr-scanner');

    if (result != null) {
      setState(() {
        _scannedQrCodeValue = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Command Center')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_scannedQrCodeValue != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Scanned QR Code: $_scannedQrCodeValue',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ElevatedButton.icon(
              onPressed: _navigateToScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to Pair New Device'),
            ),
          ],
        ),
      ),
    );
  }
}
