enum ClientType { AGENT, MOBILE, UNKNOWN }

enum DeviceStatus { ONLINE, OFFLINE, UNKNOWN }

class Device {
  final int id;
  final String name;
  final ClientType clientType;
  final DeviceStatus status;

  Device({
    required this.id,
    required this.name,
    required this.clientType,
    required this.status,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      name: json['name'] as String,
      clientType: _clientTypeFromString(json['clientType'] as String?),
      status: _deviceStatusFromString(json['status'] as String?),
    );
  }

  static ClientType _clientTypeFromString(String? type) {
    switch (type?.toUpperCase()) {
      case 'AGENT':
        return ClientType.AGENT;
      case 'MOBILE':
        return ClientType.MOBILE;
      default:
        return ClientType.UNKNOWN;
    }
  }

  static DeviceStatus _deviceStatusFromString(String? status) {
    switch (status?.toUpperCase()) {
      case 'ONLINE':
        return DeviceStatus.ONLINE;
      case 'OFFLINE':
        return DeviceStatus.OFFLINE;
      default:
        return DeviceStatus.UNKNOWN;
    }
  }
}
