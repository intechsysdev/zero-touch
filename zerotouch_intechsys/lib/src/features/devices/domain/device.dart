class ManagedDevice {
  const ManagedDevice({
    required this.id,
    required this.serialNumber,
    required this.model,
    required this.assignedUser,
    required this.createdAt,
    this.imei,
    this.manufacturer,
  });

  final String id;
  final String serialNumber;
  final String model;
  final String assignedUser;
  final DateTime createdAt;
  final String? imei;
  final String? manufacturer;
}
