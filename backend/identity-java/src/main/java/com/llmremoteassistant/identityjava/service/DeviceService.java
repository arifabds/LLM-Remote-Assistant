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
    public String initiatePairing(Long userId, String agentDeviceId, String agentDeviceName) {
        User user = User.findById(userId);
        if (user == null) throw new NotFoundException("User not found");

        Device agentDevice = Device.<Device>find("deviceId", agentDeviceId).firstResultOptional().orElse(new Device());
        agentDevice.deviceId = agentDeviceId;
        agentDevice.name = agentDeviceName;
        agentDevice.user = user;
        agentDevice.clientType = ClientType.AGENT;
        agentDevice.osType = OsType.UNKNOWN;
        agentDevice.status = DeviceStatus.OFFLINE;
        agentDevice.isPaired = false;
        agentDevice.persist();
        
        user.activePairingTokens.clear();
        String newPairingToken = UUID.randomUUID().toString();
        user.activePairingTokens.add(newPairingToken);
        return newPairingToken;
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

        Device agentDevice = Device.<Device>find("user = ?1 and clientType = ?2 and isPaired = false", user, ClientType.AGENT)
                .firstResultOptional()
                .orElseThrow(() -> new NotFoundException("No unpaired agent found for this user to complete pairing."));
        
        agentDevice.isPaired = true;
        
        Device mobileDevice = Device.<Device>find("deviceId", mobileDeviceId).firstResultOptional().orElse(new Device());
        
        mobileDevice.deviceId = mobileDeviceId;
        mobileDevice.name = mobileDeviceName;
        mobileDevice.user = user;
        mobileDevice.clientType = ClientType.MOBILE;
        mobileDevice.osType = OsType.UNKNOWN;
        mobileDevice.status = DeviceStatus.OFFLINE;
        mobileDevice.isPaired = true;
        
        agentDevice.persist();
        mobileDevice.persist();
        
        user.activePairingTokens.remove(pairingToken);
    }

    public List<Device> findDevicesByUserId(Long userId) {
        return Device.list("user.id = ?1 and isPaired = true", userId);
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
        }
    }
}