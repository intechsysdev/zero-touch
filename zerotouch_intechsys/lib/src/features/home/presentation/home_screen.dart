import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/domain/auth_session.dart';
import '../../auth/state/auth_controller.dart';
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
  String? get _customerId => widget.session.zeroTouchCustomerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerId = _customerId;
      if (customerId == null || customerId.isEmpty) {
        return;
      }

      ref
          .read(deviceControllerProvider.notifier)
          .loadDevices(
            accessToken: widget.session.accessToken,
            customerId: customerId,
          );
    });
  }

  Future<void> _openCreateDialog() async {
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const DeviceFormDialog(),
    );

    if (payload == null) {
      return;
    }

    final customerId = _customerId;
    if (customerId == null || customerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay customerId de Zero Touch asociado al usuario.',
            ),
          ),
        );
      }
      return;
    }

    await ref
        .read(deviceControllerProvider.notifier)
        .addDevice(
          accessToken: widget.session.accessToken,
          customerId: customerId,
          imei: payload['imei']!,
          serialNumber: payload['serialNumber']!,
          manufacturer: payload['manufacturer']!,
          model: payload['model']!,
          assignedUser: payload['assignedUser']!,
        );
  }

  Future<void> _deleteDevice(ManagedDevice device) async {
    final customerId = _customerId;
    if (customerId == null || customerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay customerId de Zero Touch asociado al usuario.',
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
          device: device,
        );
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceControllerProvider);
    final devices = deviceState.valueOrNull ?? const <ManagedDevice>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Zero Touch'),
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
        onRefresh: () {
          final customerId = _customerId;
          if (customerId == null || customerId.isEmpty) {
            return Future<void>.value();
          }
          return ref
              .read(deviceControllerProvider.notifier)
              .loadDevices(
                accessToken: widget.session.accessToken,
                customerId: customerId,
              );
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if ((_customerId == null || _customerId!.isEmpty))
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Este usuario no tiene customerId configurado. Contacta al administrador backend.',
                  ),
                ),
              ),
            _CompanySummaryCard(
              company: widget.session.companyName,
              adminEmail: widget.session.adminEmail,
              devicesCount: devices.length,
            ),
            const SizedBox(height: 16),
            const Text(
              'Dispositivos conectados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
            else if (devices.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No hay dispositivos registrados.'),
                ),
              )
            else
              ...devices.map(
                (item) => _DeviceTile(
                  device: item,
                  onDelete: () => _deleteDevice(item),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        label: const Text('Nuevo dispositivo'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _CompanySummaryCard extends StatelessWidget {
  const _CompanySummaryCard({
    required this.company,
    required this.adminEmail,
    required this.devicesCount,
  });

  final String company;
  final String adminEmail;
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
            const SizedBox(height: 6),
            Text(adminEmail),
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
