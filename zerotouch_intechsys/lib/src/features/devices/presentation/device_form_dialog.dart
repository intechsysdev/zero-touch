import 'package:flutter/material.dart';

import 'imei_scanner_screen.dart';

class DeviceFormDialog extends StatefulWidget {
  const DeviceFormDialog({super.key});

  @override
  State<DeviceFormDialog> createState() => _DeviceFormDialogState();
}

class _DeviceFormDialogState extends State<DeviceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imeiController = TextEditingController();
  final _serialController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _ownerController = TextEditingController();

  @override
  void dispose() {
    _imeiController.dispose();
    _serialController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  Future<void> _scanImei() async {
    final imei = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ImeiScannerScreen()),
    );

    if (imei == null || imei.trim().isEmpty) {
      return;
    }

    _imeiController.text = imei;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo dispositivo'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _imeiController,
              decoration: InputDecoration(
                labelText: 'IMEI (opcional)',
                suffixIcon: IconButton(
                  tooltip: 'Escanear IMEI',
                  onPressed: _scanImei,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _serialController,
              decoration: const InputDecoration(labelText: 'Serial number'),
              validator: (value) {
                final imei = _imeiController.text.trim();
                final serial = value?.trim() ?? '';
                if (imei.isEmpty && serial.isEmpty) {
                  return 'Ingresa IMEI o serial number';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _manufacturerController,
              decoration: const InputDecoration(labelText: 'Manufacturer'),
              validator: (value) {
                final imei = _imeiController.text.trim();
                final serial = _serialController.text.trim();
                final manufacturer = value?.trim() ?? '';
                if (imei.isEmpty && serial.isNotEmpty && manufacturer.isEmpty) {
                  return 'Requerido cuando usas serial number';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: 'Modelo'),
              validator: (value) {
                final imei = _imeiController.text.trim();
                final serial = _serialController.text.trim();
                final model = value?.trim() ?? '';
                if (imei.isEmpty && serial.isNotEmpty && model.isEmpty) {
                  return 'Requerido cuando usas serial number';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _ownerController,
              decoration: const InputDecoration(labelText: 'Area/Usuario'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo obligatorio'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.of(context).pop({
              'imei': _imeiController.text.trim(),
              'serialNumber': _serialController.text.trim(),
              'manufacturer': _manufacturerController.text.trim(),
              'model': _modelController.text.trim(),
              'assignedUser': _ownerController.text.trim(),
            });
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
