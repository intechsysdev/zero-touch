import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/auth_session.dart';
import '../../auth/state/auth_controller.dart';
import '../../devices/data/device_repository.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/device_form_dialog.dart';
import '../../devices/state/device_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.session});

  final AuthSession session;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _pageSize = 10;
  int _page = 1;
  String _selectedPlatform = 'zerotouch';

  String? get _zeroTouchCustomerId => widget.session.zeroTouchCustomerId;
  String? get _samsungCustomerId =>
      widget.session.samsungCustomerId ?? widget.session.clientId;

  String? get _activeCustomerId => _selectedPlatform == 'samsung'
      ? _samsungCustomerId
      : _zeroTouchCustomerId;

  bool get _isSamsungMode => _selectedPlatform == 'samsung';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(ManagedDevice device) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    final haystack = [
      device.serialNumber,
      device.imei ?? '',
      device.model,
      device.manufacturer ?? '',
      device.assignedUser,
    ].join(' ').toLowerCase();

    return haystack.contains(query);
  }

  @override
  void initState() {
    super.initState();
    if (widget.session.samsungAvailable && !widget.session.zeroTouchAvailable) {
      _selectedPlatform = 'samsung';
    } else {
      _selectedPlatform = widget.session.preferredEnrollment == 'samsung'
          ? 'samsung'
          : 'zerotouch';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerId = _activeCustomerId;
      if (customerId == null || customerId.isEmpty) {
        return;
      }

      ref
          .read(deviceControllerProvider.notifier)
          .loadDevices(
            accessToken: widget.session.accessToken,
            customerId: customerId,
            platform: _selectedPlatform,
          );
    });
  }

  Future<void> _reloadDevices() {
    final customerId = _activeCustomerId;
    if (customerId == null || customerId.isEmpty) {
      return Future<void>.value();
    }

    return ref
        .read(deviceControllerProvider.notifier)
        .loadDevices(
          accessToken: widget.session.accessToken,
          customerId: customerId,
          platform: _selectedPlatform,
        );
  }

  Future<void> _openCreateDialog() async {
    try {
      final options = _isSamsungMode
          ? const DeviceIdentifierOptions(
              manufacturers: [],
              modelsByManufacturer: {},
            )
          : await ref
                .read(deviceRepositoryProvider)
                .fetchIdentifierOptions(
                  accessToken: widget.session.accessToken,
                );

      if (!mounted) {
        return;
      }

      final payload = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => DeviceFormDialog(
          manufacturers: options.manufacturers,
          modelsByManufacturer: options.modelsByManufacturer,
        ),
      );

      if (payload == null) {
        return;
      }

      final customerId = _activeCustomerId;
      if (customerId == null || customerId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isSamsungMode
                    ? 'No hay customerId de Samsung Knox asociado al usuario.'
                    : 'No hay customerId de Zero Touch asociado al usuario.',
              ),
            ),
          );
        }
        return;
      }

      final identifierType =
          (payload['identifierType'] as String?)?.trim() ?? 'imei';
      final rawValues = (payload['identifiers'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      final manufacturer = (payload['manufacturer'] as String?)?.trim() ?? '';
      final model = (payload['model'] as String?)?.trim() ?? '';
      final configurationId =
          (payload['configurationId'] as String?)?.trim() ?? '';

      final summary = await ref
          .read(deviceControllerProvider.notifier)
          .addDevicesBulk(
            accessToken: widget.session.accessToken,
            customerId: customerId,
            identifierType: _isSamsungMode ? 'imei' : identifierType,
            values: rawValues,
            manufacturer: manufacturer,
            model: model,
            platform: _selectedPlatform,
            configurationId: configurationId.isEmpty ? null : configurationId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Carga finalizada: ${summary.successCount}/${summary.total} exitosos, ${summary.failedCount} fallidos.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar la carga: $error')),
        );
      }
    }
  }

  Future<void> _deleteDevice(ManagedDevice device) async {
    final customerId = _activeCustomerId;
    if (customerId == null || customerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSamsungMode
                  ? 'No hay customerId de Samsung Knox asociado al usuario.'
                  : 'No hay customerId de Zero Touch asociado al usuario.',
            ),
          ),
        );
      }
      return;
    }

    await ref
        .read(deviceControllerProvider.notifier)
        .removeDevice(
          accessToken: widget.session.accessToken,
          customerId: customerId,
          platform: _selectedPlatform,
          device: device,
        );
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceControllerProvider);
    final devices = deviceState.valueOrNull ?? const <ManagedDevice>[];
    final filteredDevices = devices.where(_matchesSearch).toList();
    final totalPages = filteredDevices.isEmpty
        ? 1
        : ((filteredDevices.length + _pageSize - 1) ~/ _pageSize);
    final currentPage = _page > totalPages ? totalPages : _page;
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > filteredDevices.length
        ? filteredDevices.length
        : (startIndex + _pageSize);
    final visibleDevices = filteredDevices.sublist(startIndex, endIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSamsungMode ? 'Panel Samsung Knox' : 'Panel Zero Touch'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reloadDevices,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isSamsungMode)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B2E6B), Color(0xFF0E4AA8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Samsung Knox Enrollment',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            if ((_activeCustomerId == null || _activeCustomerId!.isEmpty))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _isSamsungMode
                        ? 'Este usuario no tiene customerId de Samsung Knox configurado. Contacta al administrador backend.'
                        : 'Este usuario no tiene customerId de Zero Touch configurado. Contacta al administrador backend.',
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Zero-touch'),
                      selected: _selectedPlatform == 'zerotouch',
                      onSelected: widget.session.zeroTouchAvailable
                          ? (_) {
                              setState(() {
                                _selectedPlatform = 'zerotouch';
                                _page = 1;
                              });
                              _reloadDevices();
                            }
                          : null,
                    ),
                    ChoiceChip(
                      label: const Text('Samsung Knox'),
                      selected: _selectedPlatform == 'samsung',
                      onSelected: widget.session.samsungAvailable
                          ? (_) {
                              setState(() {
                                _selectedPlatform = 'samsung';
                                _page = 1;
                              });
                              _reloadDevices();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            _CompanySummaryCard(
              company: widget.session.companyName,
              devicesCount: devices.length,
            ),
            const SizedBox(height: 16),
            const Text(
              'Dispositivos conectados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _page = 1;
                });
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                labelText:
                    'Buscar por Identificador, Modelo, Fabricante u Owner',
                hintText: 'Ej: 50057711500955, Dispositivo, N/A, 1408308716',
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar busqueda',
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _page = 1;
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Mostrar:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _pageSize,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _pageSize = value;
                      _page = 1;
                    });
                  },
                ),
                const Spacer(),
                Text('Pagina $currentPage de $totalPages'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: currentPage <= 1
                        ? null
                        : () {
                            setState(() {
                              _page -= 1;
                            });
                          },
                    child: const Text('Anterior'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: currentPage >= totalPages
                        ? null
                        : () {
                            setState(() {
                              _page += 1;
                            });
                          },
                    child: const Text('Siguiente'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              filteredDevices.isEmpty
                  ? 'Mostrando 0 de 0'
                  : 'Mostrando ${startIndex + 1}-$endIndex de ${filteredDevices.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (deviceState.isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (deviceState.hasError)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Error: ${deviceState.error}'),
              )
            else if (filteredDevices.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    devices.isEmpty
                        ? 'No hay dispositivos registrados.'
                        : 'No hay coincidencias para la busqueda.',
                  ),
                ),
              )
            else
              ...visibleDevices.map(
                (item) => _DeviceTile(
                  device: item,
                  onDelete: () => _deleteDevice(item),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_activeCustomerId == null || _activeCustomerId!.isEmpty)
            ? null
            : _openCreateDialog,
        label: const Text('Nuevo dispositivo'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _CompanySummaryCard extends StatelessWidget {
  const _CompanySummaryCard({
    required this.company,
    required this.devicesCount,
  });

  final String company;
  final int devicesCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.devices_rounded),
                const SizedBox(width: 8),
                Text(
                  '$devicesCount dispositivos conectados',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onDelete});

  final ManagedDevice device;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy-MM-dd HH:mm').format(device.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text('${device.model} - ${device.serialNumber}'),
        subtitle: Text('Asignado: ${device.assignedUser} | Creado: $dateText'),
        trailing: IconButton(
          tooltip: 'Eliminar',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
