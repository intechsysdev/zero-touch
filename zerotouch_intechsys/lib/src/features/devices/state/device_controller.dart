import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_repository.dart';
import '../domain/device.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository();
});

final deviceControllerProvider =
    StateNotifierProvider<DeviceController, AsyncValue<List<ManagedDevice>>>((
      ref,
    ) {
      return DeviceController(ref.read(deviceRepositoryProvider));
    });

class DeviceController extends StateNotifier<AsyncValue<List<ManagedDevice>>> {
  DeviceController(this._repository) : super(const AsyncValue.loading());

  final DeviceRepository _repository;

  Future<void> loadDevices({
    required String accessToken,
    required String customerId,
  }) async {
    state = await AsyncValue.guard(
      () => _repository.fetchDevices(
        accessToken: accessToken,
        customerId: customerId,
      ),
    );
  }

  Future<void> addDevice({
    required String accessToken,
    required String customerId,
    required String imei,
    required String serialNumber,
    required String manufacturer,
    required String model,
    required String assignedUser,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createDevice(
        imei: imei,
        serialNumber: serialNumber,
        manufacturer: manufacturer,
        model: model,
        assignedUser: assignedUser,
        accessToken: accessToken,
        customerId: customerId,
      );
      return _repository.fetchDevices(
        accessToken: accessToken,
        customerId: customerId,
      );
    });
  }

  Future<void> removeDevice({
    required String accessToken,
    required String customerId,
    required ManagedDevice device,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteDevice(
        device: device,
        accessToken: accessToken,
        customerId: customerId,
      );
      return _repository.fetchDevices(
        accessToken: accessToken,
        customerId: customerId,
      );
    });
  }
}
