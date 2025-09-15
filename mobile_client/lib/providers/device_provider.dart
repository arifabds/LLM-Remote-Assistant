import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../repositories/device_repository.dart';

class DeviceProvider with ChangeNotifier {
  final DeviceRepository _deviceRepository = DeviceRepository();

  List<Device> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get hasOnlineAgent {
    return _devices.any((d) => d.clientType == ClientType.AGENT);
  }

  Future<void> fetchDevices() async {
    if (!_isLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _devices = await _deviceRepository.getDevices();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDeviceName(int deviceId, String newName) async {
    try {
      final updatedDevice = await _deviceRepository.updateDeviceName(
        deviceId,
        newName,
      );

      final index = _devices.indexWhere((d) => d.id == deviceId);
      if (index != -1) {
        _devices[index] = updatedDevice;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = "Failed to update name: ${e.toString()}";
      notifyListeners();
    }
  }

  Future<void> deleteDevice(int deviceId) async {
    try {
      await _deviceRepository.deleteDevice(deviceId);
      _devices.removeWhere((device) => device.id == deviceId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }
}
