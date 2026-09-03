import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';

import '../domain/device.dart';

class DeviceIdentifierOptions {
  const DeviceIdentifierOptions({
    required this.manufacturers,
    required this.modelsByManufacturer,
  });

  final List<String> manufacturers;
  final Map<String, List<String>> modelsByManufacturer;
}

class BulkClaimSummary {
  const BulkClaimSummary({
    required this.total,
    required this.successCount,
    required this.failedCount,
  });

  final int total;
  final int successCount;
  final int failedCount;
}

class DeviceRepository {
  DeviceRepository()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.backendBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );

  final Dio _dio;

  Never _throwFriendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          throw Exception(message);
        }
      }
      throw Exception(error.message ?? 'Error de red al llamar al backend.');
    }
    throw Exception(error.toString());
  }

  Future<List<ManagedDevice>> fetchDevices({
    required String accessToken,
    required String customerId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConfig.zeroTouchDevicesPath,
      queryParameters: {'customerId': customerId, 'pageSize': 50},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    final data = response.data ?? <String, dynamic>{};
    final devicesRaw = (data['devices'] as List<dynamic>? ?? const <dynamic>[]);

    final devices = devicesRaw
        .whereType<Map<String, dynamic>>()
        .map(_mapToManagedDevice)
        .toList();

    return devices..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<ManagedDevice> createDevice({
    required String imei,
    required String serialNumber,
    required String manufacturer,
    required String model,
    required String assignedUser,
    required String accessToken,
    required String customerId,
  }) async {
    final normalizedImei = imei.trim();
    final normalizedSerial = serialNumber.trim();
    final normalizedManufacturer = manufacturer.trim();
    final normalizedModel = model.trim();

    final identifier = <String, String>{};
    if (normalizedImei.isNotEmpty) {
      identifier['imei'] = normalizedImei;
    } else {
      identifier['serialNumber'] = normalizedSerial;
      identifier['manufacturer'] = normalizedManufacturer;
      identifier['model'] = normalizedModel;
    }

    try {
      await _dio.post<Map<String, dynamic>>(
        AppConfig.zeroTouchDeviceClaimPath,
        data: {'customerId': customerId, 'deviceIdentifier': identifier},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } catch (error) {
      _throwFriendlyError(error);
    }

    return ManagedDevice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      serialNumber: normalizedSerial.isNotEmpty
          ? normalizedSerial
          : normalizedImei,
      model: normalizedModel,
      assignedUser: assignedUser,
      createdAt: DateTime.now(),
      imei: normalizedImei.isNotEmpty ? normalizedImei : null,
      manufacturer: normalizedManufacturer.isNotEmpty
          ? normalizedManufacturer
          : null,
    );
  }

  Future<DeviceIdentifierOptions> fetchIdentifierOptions({
    required String accessToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConfig.zeroTouchDeviceIdentifierOptionsPath,
      queryParameters: {'forceSync': 'true'},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    final data = response.data ?? <String, dynamic>{};
    final manufacturers =
        (data['manufacturers'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();

    final rawModelsByManufacturer =
        data['modelsByManufacturer'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    final modelsByManufacturer = <String, List<String>>{};
    for (final entry in rawModelsByManufacturer.entries) {
      final values = (entry.value as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      modelsByManufacturer[entry.key] = values;
    }

    return DeviceIdentifierOptions(
      manufacturers: manufacturers,
      modelsByManufacturer: modelsByManufacturer,
    );
  }

  Future<BulkClaimSummary> bulkClaimDevices({
    required String accessToken,
    required String customerId,
    required String identifierType,
    required List<String> values,
    required String manufacturer,
    required String model,
    String? configurationId,
  }) async {
    final normalizedType = identifierType.trim().toLowerCase();
    final normalizedValues = values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (normalizedValues.isEmpty) {
      throw Exception('Debes ingresar al menos un identificador.');
    }

    final devices = normalizedValues.map((item) {
      if (normalizedType == 'imei') {
        return <String, dynamic>{'imei': item};
      }

      return <String, dynamic>{
        'serialNumber': item,
        'manufacturer': manufacturer.trim(),
        'model': model.trim(),
      };
    }).toList();

    final payload = <String, dynamic>{
      'customerId': customerId,
      'identifierType': normalizedType,
      'devices': devices,
    };

    final normalizedConfigurationId = configurationId?.trim() ?? '';
    if (normalizedConfigurationId.isNotEmpty) {
      payload['configurationId'] = normalizedConfigurationId;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConfig.zeroTouchDeviceBulkClaimPath,
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final summary =
          response.data?['summary'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      return BulkClaimSummary(
        total: (summary['total'] as num?)?.toInt() ?? normalizedValues.length,
        successCount:
            (summary['successCount'] as num?)?.toInt() ??
            normalizedValues.length,
        failedCount: (summary['failedCount'] as num?)?.toInt() ?? 0,
      );
    } catch (error) {
      _throwFriendlyError(error);
    }
  }

  Future<void> deleteDevice({
    required ManagedDevice device,
    required String accessToken,
    required String customerId,
  }) async {
    final identifier = <String, String>{};
    final imei = (device.imei ?? '').trim();
    final serial = device.serialNumber.trim();
    final manufacturer = (device.manufacturer ?? '').trim();

    if (imei.isNotEmpty) {
      identifier['imei'] = imei;
    } else {
      identifier['serialNumber'] = serial;
      if (manufacturer.isNotEmpty) {
        identifier['manufacturer'] = manufacturer;
      }
      if (device.model.trim().isNotEmpty) {
        identifier['model'] = device.model.trim();
      }
    }

    try {
      await _dio.post<Map<String, dynamic>>(
        AppConfig.zeroTouchDeviceUnclaimPath,
        data: {'deviceIdentifier': identifier},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } catch (error) {
      _throwFriendlyError(error);
    }
  }

  ManagedDevice _mapToManagedDevice(Map<String, dynamic> raw) {
    final identifier =
        (raw['deviceIdentifier'] as Map<String, dynamic>? ??
        <String, dynamic>{});

    final serial =
        (raw['serialNumber'] ??
                identifier['serialNumber'] ??
                identifier['imei'])
            .toString();
    final imei = identifier['imei']?.toString();
    final manufacturer = (raw['manufacturer'] ?? identifier['manufacturer'])
        ?.toString();
    final model = (raw['model'] ?? identifier['model'] ?? 'Dispositivo')
        .toString();
    final id = (raw['deviceId'] ?? raw['name'] ?? serial).toString();

    DateTime createdAt = DateTime.now();
    final claims = raw['claims'];
    if (claims is List && claims.isNotEmpty) {
      final firstClaim = claims.first;
      if (firstClaim is Map<String, dynamic>) {
        final dateText = firstClaim['createTime']?.toString();
        if (dateText != null) {
          createdAt = DateTime.tryParse(dateText) ?? DateTime.now();
        }
      }
    }

    return ManagedDevice(
      id: id,
      serialNumber: serial,
      model: model,
      assignedUser: 'Zero Touch',
      createdAt: createdAt,
      imei: imei,
      manufacturer: manufacturer,
    );
  }
}
