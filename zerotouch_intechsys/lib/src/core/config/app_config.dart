class AppConfig {
  const AppConfig._();

  static const String appName = 'ZeroTouch Intechsys';

  // Set with --dart-define=BACKEND_BASE_URL=https://api.yourdomain.com
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue:
        'https://intechsys-backend-prod-w2.lemondesert-86c4a20f.westus2.azurecontainerapps.io',
  );

  static const String authLoginPath = '/auth/login';

  // Never call Google Zero-touch directly from Flutter.
  // All provisioning operations must go through backend endpoints.
  static const String zeroTouchCustomersPath = '/zerotouch/customers';
  static const String zeroTouchDevicesPath = '/zerotouch/devices';
  static const String zeroTouchDeviceClaimPath = '/zerotouch/devices/claim';
  static const String zeroTouchDeviceUnclaimPath = '/zerotouch/devices/unclaim';
}
