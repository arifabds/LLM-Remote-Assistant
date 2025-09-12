import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/device_model.dart';
import '../utils/constants.dart';

class DeviceService {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$identityServiceBaseUrl/api/devices';
  static const _jwtKey = 'jwt_token';

  Future<String?> _getToken() async {
    final token = await _storage.read(key: _jwtKey);
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }
    return token;
  }

  Future<List<Device>> getPairedMobileDevices() async {
    final token = await _getToken();
    final url = Uri.parse(_baseUrl);

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> allDevicesJson = json.decode(response.body);
      return allDevicesJson
          .map((json) => Device.fromJson(json))
          .where((device) => device.clientType == ClientType.MOBILE)
          .toList();
    } else {
      throw Exception('Failed to load devices: ${response.body}');
    }
  }
}
