import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'imei_scanner_screen.dart';

class DeviceFormDialog extends StatefulWidget {
  const DeviceFormDialog({
    super.key,
    required this.manufacturers,
    required this.modelsByManufacturer,
  });

  final List<String> manufacturers;
  final Map<String, List<String>> modelsByManufacturer;

  @override
  State<DeviceFormDialog> createState() => _DeviceFormDialogState();
}

class _DeviceFormDialogState extends State<DeviceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bulkIdentifiersController = TextEditingController();
  final _customManufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _configurationIdController = TextEditingController();

  String _identifierType = 'imei';
  String? _selectedManufacturer;

  List<String> _mergeUnique(List<String> current, List<String> incoming) {
    final seen = <String>{};
    final merged = <String>[];
    for (final item in [...current, ...incoming]) {
      final normalized = item.trim();
      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      merged.add(normalized);
    }
    return merged;
  }

  List<String> _splitSimpleCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i += 1) {
      final char = line[i];
      if (char == '"') {
        if (insideQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i += 1;
        } else {
          insideQuotes = !insideQuotes;
        }
        continue;
      }

      if (char == ',' && !insideQuotes) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    values.add(buffer.toString().trim());
    return values;
  }

  List<String> _extractFromCsvLikeText(String source) {
    final lines = source
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const [];
    }

    final header = _splitSimpleCsvLine(
      lines.first,
    ).map((item) => item.toLowerCase()).toList();

    final hasHeader = header.any(
      (item) =>
          item == 'modemid' ||
          item == 'imei' ||
          item == 'serial' ||
          item == 'serialnumber',
    );

    if (!hasHeader) {
      return _parseIdentifiersFromText(source);
    }

    int indexOf(String key) => header.indexOf(key);

    final modemIdIndex = indexOf('modemid');
    final imeiIndex = indexOf('imei');
    final serialIndex = indexOf('serial');
    final serialNumberIndex = indexOf('serialnumber');

    final extracted = <String>[];
    for (int i = 1; i < lines.length; i += 1) {
      final columns = _splitSimpleCsvLine(lines[i]);

      if (_identifierType == 'imei') {
        final candidates = <int>[
          modemIdIndex,
          imeiIndex,
        ].where((index) => index >= 0).toList();
        for (final index in candidates) {
          if (index < columns.length) {
            final value = columns[index].trim();
            if (value.isNotEmpty) {
              extracted.add(value);
              break;
            }
          }
        }
      } else {
        final candidates = <int>[
          serialIndex,
          serialNumberIndex,
        ].where((index) => index >= 0).toList();
        for (final index in candidates) {
          if (index < columns.length) {
            final value = columns[index].trim();
            if (value.isNotEmpty) {
              extracted.add(value);
              break;
            }
          }
        }
      }
    }

    return extracted;
  }

  @override
  void dispose() {
    _bulkIdentifiersController.dispose();
    _customManufacturerController.dispose();
    _modelController.dispose();
    _configurationIdController.dispose();
    super.dispose();
  }

  Future<void> _scanImei() async {
    final imei = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ImeiScannerScreen()),
    );

    if (imei == null || imei.trim().isEmpty) {
      return;
    }

    final current = _bulkIdentifiersController.text.trim();
    _bulkIdentifiersController.text = current.isEmpty
        ? imei
        : '$current\n$imei';
  }

  List<String> _parseIdentifiersFromText(String text) {
    return text
        .split(RegExp(r'[\s,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _parseIdentifiers() {
    return _parseIdentifiersFromText(_bulkIdentifiersController.text);
  }

  Future<void> _importIdentifiersFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final pickedFile = result.files.first;
    final bytes = pickedFile.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo leer el archivo seleccionado.'),
        ),
      );
      return;
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    final imported = _extractFromCsvLikeText(text);
    if (imported.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se detectaron identificadores validos en el archivo.',
          ),
        ),
      );
      return;
    }

    final current = _parseIdentifiers();
    final merged = _mergeUnique(current, imported);

    setState(() {
      _bulkIdentifiersController.text = merged.join('\n');
    });

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Importados ${imported.length} registros. Total actual: ${merged.length}.',
        ),
      ),
    );
  }

  Future<void> _copyCsvTemplate() async {
    final template = _identifierType == 'imei'
        ? 'modemtype,modemid,profiletype,owner\nIMEI,123456789012345,ZERO_TOUCH,OWNER_ID\nIMEI,234567890123456,ZERO_TOUCH,OWNER_ID\n'
        : 'serial,model,manufacturer,profiletype,owner\nSN-001,SM-A155M,Samsung,ZERO_TOUCH,OWNER_ID\nSN-002,Redmi-12,Xiaomi,ZERO_TOUCH,OWNER_ID\n';

    await Clipboard.setData(ClipboardData(text: template));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plantilla CSV copiada al portapapeles.')),
    );
  }

  String _effectiveManufacturer() {
    if (_selectedManufacturer != null && _selectedManufacturer!.isNotEmpty) {
      return _selectedManufacturer!;
    }
    return _customManufacturerController.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final selectedModels =
        widget.modelsByManufacturer[_selectedManufacturer] ?? const <String>[];
    final parsedCount = _parseIdentifiers().length;

    return AlertDialog(
      title: const Text('Carga masiva de dispositivos'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tipo de identificador'),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'imei',
                      label: Text('IMEI'),
                      icon: Icon(Icons.dialpad_rounded),
                    ),
                    ButtonSegment<String>(
                      value: 'serial',
                      label: Text('Serial + Marca + Modelo'),
                      icon: Icon(Icons.confirmation_number_rounded),
                    ),
                  ],
                  selected: {_identifierType},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _identifierType = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_identifierType == 'imei')
                      OutlinedButton.icon(
                        onPressed: _scanImei,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Escanear IMEI'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _importIdentifiersFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Importar CSV/TXT'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _copyCsvTemplate,
                      icon: const Icon(Icons.copy_all_rounded),
                      label: const Text('Copiar plantilla CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bulkIdentifiersController,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _identifierType == 'imei'
                        ? 'IMEI(s): uno por linea o separados por coma'
                        : 'Serial(es): uno por linea o separados por coma',
                    alignLabelWithHint: true,
                  ),
                  validator: (_) {
                    final values = _parseIdentifiers();
                    if (values.isEmpty) {
                      return 'Ingresa al menos un identificador';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Detectados: $parsedCount identificadores',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_identifierType == 'serial') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedManufacturer,
                    decoration: const InputDecoration(
                      labelText: 'Marca disponible',
                    ),
                    items: [
                      ...widget.manufacturers.map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: '__custom__',
                        child: Text('Otra marca (manual)'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        if (value == '__custom__') {
                          _selectedManufacturer = null;
                        } else {
                          _selectedManufacturer = value;
                        }
                      });
                    },
                    validator: (_) {
                      final manufacturer = _effectiveManufacturer();
                      if (_identifierType == 'serial' && manufacturer.isEmpty) {
                        return 'Marca requerida para serial';
                      }
                      return null;
                    },
                  ),
                  if (_selectedManufacturer == null) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _customManufacturerController,
                      decoration: const InputDecoration(
                        labelText: 'Marca (manual)',
                      ),
                      validator: (value) {
                        if (_identifierType == 'serial' &&
                            _selectedManufacturer == null &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Ingresa la marca';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: selectedModels.isEmpty
                          ? 'Modelo'
                          : 'Modelo (sugeridos: ${selectedModels.take(3).join(', ')})',
                    ),
                    validator: (value) {
                      if (_identifierType == 'serial' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Modelo requerido para serial';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _configurationIdController,
                  decoration: const InputDecoration(
                    labelText: 'Configuration ID (opcional)',
                  ),
                ),
              ],
            ),
          ),
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

            final manufacturer = _effectiveManufacturer();

            Navigator.of(context).pop({
              'identifierType': _identifierType,
              'identifiers': _parseIdentifiers(),
              'manufacturer': manufacturer,
              'model': _modelController.text.trim(),
              'configurationId': _configurationIdController.text.trim(),
            });
          },
          child: const Text('Cargar'),
        ),
      ],
    );
  }
}
