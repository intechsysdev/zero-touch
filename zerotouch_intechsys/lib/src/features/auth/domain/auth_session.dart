class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.companyName,
    required this.clientId,
    required this.zeroTouchAvailable,
    required this.samsungAvailable,
    this.zeroTouchCustomerName,
    this.zeroTouchCustomerId,
    this.samsungCustomerId,
    this.preferredEnrollment,
  });

  final String accessToken;
  final String companyName;
  final String clientId;
  final bool zeroTouchAvailable;
  final bool samsungAvailable;
  final String? zeroTouchCustomerName;
  final String? zeroTouchCustomerId;
  final String? samsungCustomerId;
  final String? preferredEnrollment;
}
