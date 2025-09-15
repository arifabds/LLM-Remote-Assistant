import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class AuthRepository {
  final _storage = const FlutterSecureStorage();
  static const _jwtKey = 'jwt_token';

  Future<String> loginAndGetToken(String username, String password) async {
    final url = Uri.parse('$identityServiceBaseUrl/api/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception(
        'Login failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<String> initiatePairing({
    required String token,
    required String agentDeviceId,
    required String agentDeviceName,
  }) async {
    final url = Uri.parse(
      '$identityServiceBaseUrl/api/devices/initiate-pairing',
    );
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'agentDeviceId': agentDeviceId,
        'agentDeviceName': agentDeviceName,
      }),
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to initiate pairing: ${response.body}');
    }
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _jwtKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _jwtKey);
  }

  Future<void> logout() async {
    await _storage.delete(key: _jwtKey);
  }

  Future<String?> getDeviceId(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> saveDeviceId(String key, String deviceId) async {
    await _storage.write(key: key, value: deviceId);
  }

  Future<void> deleteValue(String key) async {
    await _storage.delete(key: key);
  }
}
