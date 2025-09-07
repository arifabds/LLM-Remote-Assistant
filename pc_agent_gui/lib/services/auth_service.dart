import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  static const _jwtKey = 'jwt_token';

  Future<void> login(String username, String password) async {
    final url = Uri.parse('$identityServiceBaseUrl/api/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        await _storage.write(key: _jwtKey, value: response.body);
      } else {
        throw Exception(
          'Login failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred during login: $e');
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _jwtKey);
  }

  Future<void> logout() async {
    await _storage.delete(key: _jwtKey);
  }
}
