// ignore_for_file: avoid_print
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

    print('═══════════════════════════════════════════════════════');
    print('[AUTH LOGIN] Iniciando sesión...');
    print('[AUTH LOGIN] Base URL: "${AppConfig.backendBaseUrl}"');
    print('[AUTH LOGIN] Endpoint: "${AppConfig.authLoginPath}"');
    print(
      '[AUTH LOGIN] URL Completa: "${AppConfig.backendBaseUrl}${AppConfig.authLoginPath}"',
    );
    print('[AUTH LOGIN] Client ID: "$normalizedClientId"');
    print(
      '[AUTH LOGIN] Email: "${normalizedEmail.isEmpty ? '(sin correo)' : normalizedEmail}"',
    );
    print('═══════════════════════════════════════════════════════');

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConfig.authLoginPath,
        data: {
          'email': normalizedEmail,
          'password': normalizedClientId,
          'clientId': normalizedClientId,
        },
      );

      print('✅ [AUTH SUCCESS] Status: ${response.statusCode}');
      print('✅ [AUTH SUCCESS] Body: ${response.data}');

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
      print('❌ [AUTH DIO ERROR]:');
      print('   - Type: ${error.type}');
      print('   - Message: ${error.message}');
      print('   - Request URI: ${error.requestOptions.uri}');
      print('   - Status Code: ${error.response?.statusCode}');
      print('   - Response Data: ${error.response?.data}');

      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'] ?? responseData['error'];
        if (message != null) {
          print('   - Server Message: $message');
          throw Exception(message.toString());
        }
      }

      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        throw Exception(
          'Credenciales o Client ID incorrectos (HTTP ${error.response?.statusCode}).',
        );
      }

      if (error.response?.statusCode != null) {
        throw Exception(
          'Error del servidor (${error.response!.statusCode}): ${error.response?.statusMessage ?? error.message}',
        );
      }

      throw Exception(
        'Error de conexión con el servidor: ${error.message ?? "URL inalcanzable"}',
      );
    } catch (e, stack) {
      print('❌ [AUTH GENERAL ERROR]: $e');
      print('   Stack: $stack');
      rethrow;
    }
  }
}
