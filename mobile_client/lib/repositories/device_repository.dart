import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/device_model.dart';
import '../utils/constants.dart';
import '../services/device_identity_service.dart';

class DeviceRepository {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$identityServiceBaseUrl/api/devices';

  Future<String> _getToken() async {
    final token = await _storage.read(key: 'jwt');
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }
    return token;
  }

  Future<List<Device>> getDevices() async {
    final token = await _getToken();
    final url = Uri.parse(_baseUrl);

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> devicesJson = json.decode(response.body);
      return devicesJson.map((json) => Device.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load devices: ${response.body}');
    }
  }

  Future<Device> updateDeviceName(int deviceId, String newName) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/$deviceId');

    final response = await http.put(
      url,
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'text/plain'},
      body: newName,
    );

    if (response.statusCode == 200) {
      return Device.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update device name: ${response.body}');
    }
  }

  Future<void> deleteDevice(int deviceId) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/$deviceId');

    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete device: ${response.body}');
    }
  }

  Future<void> pairDevice({
    required String pairingToken,
    required String deviceName,
  }) async {
    final token = await _getToken();
    final deviceId = await DeviceIdentityService().getOrCreateDeviceId();
    final url = Uri.parse('$_baseUrl/pair');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'pairingToken': pairingToken,
        'mobileDeviceId': deviceId,
        'mobileDeviceName': deviceName,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Device pairing failed: ${response.body}');
    }
  }
}
