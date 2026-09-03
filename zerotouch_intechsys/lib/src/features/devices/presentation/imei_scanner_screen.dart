import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ImeiScannerScreen extends StatefulWidget {
  const ImeiScannerScreen({super.key});

  @override
  State<ImeiScannerScreen> createState() => _ImeiScannerScreenState();
}

class _ImeiScannerScreenState extends State<ImeiScannerScreen> {
  bool _handled = false;

  String _extractImei(String? rawValue) {
    if (rawValue == null) {
      return '';
    }

    final value = rawValue.trim();
    final match = RegExp(r'\b\d{15}\b').firstMatch(value);
    if (match != null) {
      return match.group(0) ?? '';
    }

    return value;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }

    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final imei = _extractImei(barcode?.rawValue);
    if (imei.isEmpty) {
      return;
    }

    _handled = true;
    Navigator.of(context).pop(imei);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear IMEI')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
            ),
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Enfoca el codigo de barras o QR del equipo para capturar el IMEI.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
