package com.llmremoteassistant.identityjava.service;

import com.llmremoteassistant.identityjava.model.*;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class DeviceService {

    @Transactional
    public void initiatePairing(Long userId, String pairingToken, String agentDeviceId, String agentDeviceName) {
        User user = User.findById(userId);
        if (user == null) throw new NotFoundException("User not found");

        if (Device.find("deviceId", agentDeviceId).firstResultOptional().isEmpty()) {
            Device agentDevice = new Device();
            agentDevice.deviceId = agentDeviceId;
            agentDevice.name = agentDeviceName;
            agentDevice.user = user;
            agentDevice.clientType = ClientType.AGENT;
            agentDevice.osType = OsType.UNKNOWN; 
            agentDevice.status = DeviceStatus.OFFLINE;
            agentDevice.persist();
        }

        user.activePairingTokens.add(pairingToken);
    }

     @Transactional
    public void pairMobileDevice(Long mobileUserId, String pairingToken, String mobileDeviceId, String mobileDeviceName) {
        if (pairingToken == null || pairingToken.isBlank() || mobileDeviceName == null || mobileDeviceName.isBlank() || mobileDeviceId == null || mobileDeviceId.isBlank()) {
            throw new BadRequestException("Token, device ID and name must not be empty.");
        }

        List<User> users = User.list("?1 MEMBER OF activePairingTokens", pairingToken);
        if (users.isEmpty()) throw new BadRequestException("Invalid or expired pairing token.");
        
        User user = users.get(0);
        if (!user.id.equals(mobileUserId)) throw new BadRequestException("User ID mismatch.");

        if (Device.find("deviceId", mobileDeviceId).firstResultOptional().isEmpty()) {
            Device mobileDevice = new Device();
            mobileDevice.deviceId = mobileDeviceId;
            mobileDevice.name = mobileDeviceName;
            mobileDevice.user = user;
            mobileDevice.clientType = ClientType.MOBILE;
            mobileDevice.osType = OsType.UNKNOWN;
            mobileDevice.status = DeviceStatus.OFFLINE;
            mobileDevice.persist();
        }
        
        user.activePairingTokens.remove(pairingToken);
    }

    public List<Device> findDevicesByUserId(Long userId) {
        return Device.list("user.id", userId);
    }

    @Transactional
    public Device updateDeviceName(Long userId, Long deviceId, String newName) {
        Device device = Device.findById(deviceId);
        if (device == null || !device.user.id.equals(userId)) {
            throw new NotFoundException("Device not found or access denied.");
        }
        device.name = newName;
        device.persist();
        return device;
    }

    @Transactional
    public void deleteDevice(Long userId, Long deviceId) {
        Device device = Device.findById(deviceId);
        if (device != null && device.user.id.equals(userId)) {
            device.delete();
        } else {
            //Empty due to security concerns
        }
    }

    @Transactional
    public void updateDeviceStatusByDeviceId(String deviceId, DeviceStatus status) {
        Device.update("status = ?1 where deviceId = ?2", status, deviceId);
    }
}