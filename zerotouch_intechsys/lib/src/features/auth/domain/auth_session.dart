class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.companyName,
    required this.adminEmail,
    required this.clientId,
    this.zeroTouchCustomerName,
    this.zeroTouchCustomerId,
  });

  final String accessToken;
  final String companyName;
  final String adminEmail;
  final String clientId;
  final String? zeroTouchCustomerName;
  final String? zeroTouchCustomerId;
}
