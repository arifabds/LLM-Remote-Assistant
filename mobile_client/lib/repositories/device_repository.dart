import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/device_model.dart';
import '../utils/constants.dart';
import '../services/device_identity_service.dart';

class DeviceRepository {
  final Stopwatch _logStopwatch = Stopwatch()..start();
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = '$identityServiceBaseUrl/api/devices';

  Future<String> _getToken() async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-GETTOKEN-START] Attempting to get token from secure storage.',
    );
    final token = await _storage.read(key: 'jwt');
    if (token == null) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-GETTOKEN-FAIL] Token not found. Throwing exception.',
      );
      throw Exception('Authentication token not found. Please log in again.');
    }
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-GETTOKEN-SUCCESS] Token found successfully.',
    );
    return token;
  }

  Future<List<Device>> getDevices() async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-GETDEVICES-START] Starting to fetch devices.',
    );
    final token = await _getToken();
    final url = Uri.parse(_baseUrl);

    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-GETDEVICES-HTTP-REQ] Sending GET request to $url.',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-GETDEVICES-HTTP-RESP] Received response with status: ${response.statusCode}.',
    );

    if (response.statusCode == 200) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-GETDEVICES-DECODE-START] Decoding successful response body.',
      );
      final List<dynamic> devicesJson = json.decode(response.body);
      final deviceList = devicesJson
          .map((json) => Device.fromJson(json))
          .toList();
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-GETDEVICES-SUCCESS] Decoded ${deviceList.length} devices. Returning list.',
      );
      return deviceList;
    } else {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-GETDEVICES-FAIL] Request failed. Throwing exception.',
      );
      throw Exception('Failed to load devices: ${response.body}');
    }
  }

  Future<Device> updateDeviceName(int deviceId, String newName) async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-UPDATE-START] Starting to update device name for ID: $deviceId to "$newName".',
    );
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/$deviceId');

    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-UPDATE-HTTP-REQ] Sending PUT request to $url.',
    );
    final response = await http.put(
      url,
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'text/plain'},
      body: newName,
    );
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-UPDATE-HTTP-RESP] Received response with status: ${response.statusCode}.',
    );

    if (response.statusCode == 200) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-UPDATE-DECODE-START] Decoding successful response body.',
      );
      final updatedDevice = Device.fromJson(json.decode(response.body));
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-UPDATE-SUCCESS] Decoded updated device. Returning device.',
      );
      return updatedDevice;
    } else {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-UPDATE-FAIL] Request failed. Throwing exception.',
      );
      throw Exception('Failed to update device name: ${response.body}');
    }
  }

  Future<void> deleteDevice(int deviceId) async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DELETE-START] Starting to delete device with ID: $deviceId.',
    );
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl/$deviceId');

    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DELETE-HTTP-REQ] Sending DELETE request to $url.',
    );
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DELETE-HTTP-RESP] Received response with status: ${response.statusCode}.',
    );

    if (response.statusCode != 204) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DELETE-FAIL] Request failed. Throwing exception.',
      );
      throw Exception('Failed to delete device: ${response.body}');
    }
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DELETE-SUCCESS] Device deleted successfully.',
    );
  }

  Future<void> pairDevice({
    required String pairingToken,
    required String deviceName,
  }) async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PAIR-START] Starting to pair device with token: "$pairingToken".',
    );
    final token = await _getToken();
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PAIR-GET-ID] Getting or creating mobile device ID.',
    );
    final deviceId = await DeviceIdentityService().getOrCreateDeviceId();
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PAIR-GOT-ID] Using mobile device ID: $deviceId.',
    );
    final url = Uri.parse('$_baseUrl/pair');

    final requestBody = {
      'pairingToken': pairingToken,
      'mobileDeviceId': deviceId,
      'mobileDeviceName': deviceName,
    };
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PAIR-HTTP-REQ] Sending POST request to $url with body: ${jsonEncode(requestBody)}.',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PAIR-HTTP-RESP] Received response from \'/pair\'. Status: ${response.statusCode}.',
      );

      if (response.statusCode != 201) {
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PAIR-THROW-EXC] Pairing failed with status ${response.statusCode}. Response body: ${response.body}. Throwing exception.',
        );
        throw Exception('Device pairing failed: ${response.body}');
      }
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PAIR-SUCCESS] Pairing successful.',
      );
    } catch (e) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-PAIR-CATCH-EXC] Caught an exception during pairing request: ${e.toString()}',
      );
      rethrow;
    }
  }
}
