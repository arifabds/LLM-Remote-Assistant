import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        // controller: MobileScannerController(
        //   detectionSpeed: DetectionSpeed.normal,
        //   facing: CameraFacing.back,
        // ),
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? qrCodeValue = barcodes.first.rawValue;
            if (qrCodeValue != null) {
              context.pop(qrCodeValue);
            }
          }
        },
      ),
    );
  }
}
