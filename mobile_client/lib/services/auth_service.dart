import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

  Future<void> register({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$identityServiceBaseUrl/api/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode != 201) {
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('An error occurred during registration: $e');
    }
  }

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$identityServiceBaseUrl/api/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('An error occurred during login: $e');
    }
  }

  Future<void> pairDevice({
    required String pairingToken,
    required String deviceName,
  }) async {
    final url = Uri.parse('$identityServiceBaseUrl/api/devices/pair');

    final token = await _storage.read(key: 'jwt');
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'pairingToken': pairingToken,
          'deviceName': deviceName,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Device pairing failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('An error occurred during device pairing: $e');
    }
  }
}
