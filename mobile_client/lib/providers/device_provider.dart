import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../services/device_service.dart';

class DeviceProvider with ChangeNotifier {
  final DeviceService _deviceService = DeviceService();
  Timer? _pollingTimer;

  List<Device> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get hasOnlineAgent {
    return _devices.any(
      (device) =>
          device.clientType == ClientType.AGENT &&
          device.status == DeviceStatus.ONLINE,
    );
  }

  DeviceProvider() {
    startPolling();
  }

  Future<void> fetchDevices({bool isManualRefresh = false}) async {
    if (isManualRefresh || _devices.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    _errorMessage = null;

    try {
      _devices = await _deviceService.getDevices();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDeviceName(int deviceId, String newName) async {
    try {
      await _deviceService.updateDeviceName(deviceId, newName);
      await fetchDevices();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteDevice(int deviceId) async {
    try {
      await _deviceService.deleteDevice(deviceId);
      _devices.removeWhere((device) => device.id == deviceId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  void startPolling() {
    if (_pollingTimer?.isActive ?? false) return;

    fetchDevices(isManualRefresh: true);

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      fetchDevices(isManualRefresh: false);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
