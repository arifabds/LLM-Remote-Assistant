import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../repositories/device_repository.dart';

class DeviceProvider with ChangeNotifier {
  final Stopwatch _logStopwatch = Stopwatch()..start();
  final DeviceRepository _deviceRepository = DeviceRepository();

  List<Device> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  DeviceProvider() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-INIT] DeviceProvider initialized.',
    );
  }

  bool get hasOnlineAgent {
    final result = _devices.any((d) => d.clientType == ClientType.AGENT);
    // Bu getter sıkça çağrılabileceği için loglamayı yorum satırı içinde tutmak daha verimlidir.
    // Gerekirse aktive edilebilir.
    // debugPrint('[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-CHECK-AGENT] hasOnlineAgent checked. Result: $result');
    return result;
  }

  Future<void> fetchDevices() async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-FETCH-START] fetchDevices called.',
    );
    if (!_isLoading) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-FETCH-SET-LOADING] Setting _isLoading to true and notifying listeners.',
      );
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    } else {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-FETCH-ALREADY-LOADING] fetchDevices called while already loading. Aborting.',
      );
      return;
    }

    try {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-FETCH-REPO-CALL] Calling _deviceRepository.getDevices().',
      );
      _devices = await _deviceRepository.getDevices();
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-FETCH-REPO-SUCCESS] Successfully fetched ${_devices.length} devices.',
      );
    } catch (e) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-FETCH-REPO-FAIL] Caught an exception: ${e.toString()}.',
      );
      _errorMessage = e.toString();
    } finally {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-FETCH-FINALLY] Setting _isLoading to false and notifying listeners.',
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDeviceName(int deviceId, String newName) async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-UPDATE-START] updateDeviceName called for deviceId: $deviceId, newName: "$newName".',
    );
    try {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-UPDATE-REPO-CALL] Calling _deviceRepository.updateDeviceName().',
      );
      final updatedDevice = await _deviceRepository.updateDeviceName(
        deviceId,
        newName,
      );
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-UPDATE-REPO-SUCCESS] Successfully updated device name.',
      );

      final index = _devices.indexWhere((d) => d.id == deviceId);
      if (index != -1) {
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-UPDATE-STATE] Found device in local list at index $index. Updating state.',
        );
        _devices[index] = updatedDevice;
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-UPDATE-NOTIFY] Notifying listeners about state change.',
        );
        notifyListeners();
      } else {
        debugPrint(
          '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-UPDATE-STATE-FAIL] Device ID $deviceId not found in local list after update. State not updated.',
        );
      }
    } catch (e) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-UPDATE-FAIL] Caught an exception: ${e.toString()}.',
      );
      _errorMessage = "Failed to update name: ${e.toString()}";
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-UPDATE-NOTIFY-FAIL] Notifying listeners about the error.',
      );
      notifyListeners();
    }
  }

  Future<void> deleteDevice(int deviceId) async {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-DELETE-START] deleteDevice called for deviceId: $deviceId.',
    );
    try {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-DELETE-REPO-CALL] Calling _deviceRepository.deleteDevice().',
      );
      await _deviceRepository.deleteDevice(deviceId);
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-DELETE-REPO-SUCCESS] Successfully deleted device via repository.',
      );
      final originalLength = _devices.length;
      _devices.removeWhere((device) => device.id == deviceId);
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-DELETE-STATE] Removed device from local list. List length changed from $originalLength to ${_devices.length}.',
      );
    } catch (e) {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-DELETE-FAIL] Caught an exception: ${e.toString()}.',
      );
      _errorMessage = e.toString();
    } finally {
      debugPrint(
        '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-DELETE-FINALLY] Notifying listeners.',
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    debugPrint(
      '[${_logStopwatch.elapsedMilliseconds}ms] [LOG-DEVPROV-DISPOSE] DeviceProvider disposed.',
    );
    super.dispose();
  }
}
