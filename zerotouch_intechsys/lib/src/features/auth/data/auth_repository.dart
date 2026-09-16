import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';

import '../domain/auth_session.dart';

class AuthRepository {
  AuthRepository()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.backendBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

  final Dio _dio;

  Future<AuthSession> signIn({
    required String clientId,
    String email = '',
  }) async {
    if (clientId.trim().isEmpty) {
      throw Exception('Client ID is required.');
    }

    final normalizedClientId = clientId.trim();
    final normalizedEmail = email.trim();

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConfig.authLoginPath,
        data: {
          'email': normalizedEmail,
          'password': normalizedClientId,
          'clientId': normalizedClientId,
        },
      );

      final data = response.data;
      if (data == null) {
        throw Exception('Empty response from authentication service.');
      }

      final accessToken = (data['accessToken'] ?? data['token'] ?? '')
          .toString();
      if (accessToken.isEmpty) {
        throw Exception('Authentication service did not return access token.');
      }

      final zeroTouchCustomerName = data['zeroTouchCustomerName']?.toString();
      final zeroTouchCustomerId =
          data['zeroTouchCustomerId']?.toString() ??
          (zeroTouchCustomerName?.split('/').last);
      final samsungCustomerId =
          data['samsungCustomerId']?.toString() ?? normalizedClientId;
      final preferredEnrollment = data['preferredEnrollment']?.toString();

      final zeroTouchAvailable =
          data['zeroTouchAvailable'] == true ||
          (zeroTouchCustomerId != null && zeroTouchCustomerId.isNotEmpty);
      final samsungAvailable =
          data['samsungAvailable'] == true || samsungCustomerId.isNotEmpty;

      return AuthSession(
        accessToken: accessToken,
        companyName: (data['companyName'] ?? data['company'] ?? 'Intechsys')
            .toString(),
        clientId: (data['clientId'] ?? normalizedClientId).toString(),
        zeroTouchAvailable: zeroTouchAvailable,
        samsungAvailable: samsungAvailable,
        zeroTouchCustomerName: zeroTouchCustomerName,
        zeroTouchCustomerId: zeroTouchCustomerId,
        samsungCustomerId: samsungCustomerId,
        preferredEnrollment: preferredEnrollment,
      );
    } on DioException catch (error) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'] ?? responseData['error'];
        if (message != null) {
          throw Exception(message.toString());
        }
      }

      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        throw Exception('Credenciales o Client ID incorrectos.');
      }

      throw Exception('No fue posible iniciar sesion en este momento.');
    }
  }
}
