enum ClientType { AGENT, MOBILE, UNKNOWN }

class Device {
  final int id;
  final String name;
  final ClientType clientType;

  Device({required this.id, required this.name, required this.clientType});

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      name: json['name'] as String,
      clientType: _clientTypeFromString(json['clientType'] as String?),
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
}
