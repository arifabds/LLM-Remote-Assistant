package com.llmremoteassistant.identityjava.service;

import com.llmremoteassistant.identityjava.model.*;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.jboss.logging.Logger;

@ApplicationScoped
public class DeviceService {

    private static final Logger LOG = Logger.getLogger(DeviceService.class);
    private static final Instant startTime = Instant.now();
    private long ms() { return Duration.between(startTime, Instant.now()).toMillis(); }

    @Transactional
    public String initiatePairing(Long userId, String agentDeviceId, String agentDeviceName) {
        LOG.infof("[%dms] [LOG-JAVA-INITPAIR-START] initiatePairing called for userId: %d, agentDeviceId: %s", ms(), userId, agentDeviceId);
        User user = User.findById(userId);
        if (user == null) {
            LOG.warnf("[%dms] [LOG-JAVA-INITPAIR-FAIL] User not found for ID: %d. Throwing NotFoundException.", ms(), userId);
            throw new NotFoundException("User not found");
        }
        LOG.infof("[%dms] [LOG-JAVA-INITPAIR-USER-FOUND] User %s found.", ms(), user.username);

        Device agentDevice = Device.<Device>find("deviceId", agentDeviceId).firstResultOptional().orElse(new Device());
        LOG.infof("[%dms] [LOG-JAVA-INITPAIR-DEVICE-CHECK] Device with deviceId %s exists in DB: %b.", ms(), agentDeviceId, (agentDevice.id != null));
        
        agentDevice.deviceId = agentDeviceId;
        agentDevice.name = agentDeviceName;
        agentDevice.user = user;
        agentDevice.clientType = ClientType.AGENT;
        agentDevice.osType = OsType.UNKNOWN;
        agentDevice.status = DeviceStatus.OFFLINE;
        agentDevice.isPaired = false;
        agentDevice.persist();
        LOG.infof("[%dms] [LOG-JAVA-INITPAIR-DEVICE-PERSIST] Agent device record (ID: %d) created/updated and persisted.", ms(), agentDevice.id);
        
        user.activePairingTokens.clear();
        LOG.infof("[%dms] [LOG-JAVA-INITPAIR-CLEAR-TOKENS] Cleared any existing pairing tokens for user %s.", ms(), user.username);
        String newPairingToken = UUID.randomUUID().toString();
        user.activePairingTokens.add(newPairingToken);
        LOG.infof("[%dms] [LOG-JAVA-INITPAIR-SUCCESS] Generated and added new pairing token for user. Returning token.");
        return newPairingToken;
    }

    @Transactional
    public void pairMobileDevice(Long mobileUserId, String pairingToken, String mobileDeviceId, String mobileDeviceName) {
        LOG.infof("[%dms] [LOG-JAVA-PAIR-START] pairMobileDevice called for mobileUserId: %d, pairingToken: %s, mobileDeviceId: %s", ms(), mobileUserId, pairingToken, mobileDeviceId);
        if (pairingToken == null || pairingToken.isBlank() || mobileDeviceName == null || mobileDeviceName.isBlank() || mobileDeviceId == null || mobileDeviceId.isBlank()) {
            LOG.warnf("[%dms] [LOG-JAVA-PAIR-FAIL] A required parameter is null or blank. Throwing BadRequestException.", ms());
            throw new BadRequestException("Token, device ID and name must not be empty.");
        }
        List<User> users = User.list("?1 MEMBER OF activePairingTokens", pairingToken);
        if (users.isEmpty()) {
            LOG.warnf("[%dms] [LOG-JAVA-PAIR-FAIL] No user found for the provided pairing token. Throwing BadRequestException.", ms());
            throw new BadRequestException("Invalid or expired pairing token.");
        }
        
        User user = users.get(0);
        LOG.infof("[%dms] [LOG-JAVA-PAIR-USER-FOUND] Found user %s (ID: %d) for pairing token.", ms(), user.username, user.id);
        if (!user.id.equals(mobileUserId)) {
            LOG.warnf("[%dms] [LOG-JAVA-PAIR-FAIL] JWT User ID (%d) does not match token's User ID (%d). Throwing BadRequestException.", ms(), mobileUserId, user.id);
            throw new BadRequestException("User ID mismatch.");
        }

        Device agentDevice = Device.<Device>find("user = ?1 and clientType = ?2 and isPaired = false", user, ClientType.AGENT)
                .firstResultOptional()
                .orElseThrow(() -> {
                    LOG.warnf("[%dms] [LOG-JAVA-PAIR-FAIL] No unpaired AGENT device found for user %s. Throwing NotFoundException.", ms(), user.username);
                    return new NotFoundException("No unpaired agent found for this user to complete pairing.");
                });
        LOG.infof("[%dms] [LOG-JAVA-PAIR-AGENT-FOUND] Found unpaired agent device (ID: %d, Name: %s).", ms(), agentDevice.id, agentDevice.name);
        
        agentDevice.isPaired = true;
        
        Device mobileDevice = Device.<Device>find("deviceId", mobileDeviceId).firstResultOptional().orElse(new Device());
        LOG.infof("[%dms] [LOG-JAVA-PAIR-MOBILE-CHECK] Mobile device with deviceId %s exists in DB: %b.", ms(), mobileDeviceId, (mobileDevice.id != null));
        
        mobileDevice.deviceId = mobileDeviceId;
        mobileDevice.name = mobileDeviceName;
        mobileDevice.user = user;
        mobileDevice.clientType = ClientType.MOBILE;
        mobileDevice.osType = OsType.UNKNOWN;
        mobileDevice.status = DeviceStatus.OFFLINE;
        mobileDevice.isPaired = true;
        
        agentDevice.persist();
        mobileDevice.persist();
        LOG.infof("[%dms] [LOG-JAVA-PAIR-PERSIST] Persisted both agent (ID: %d) and mobile (ID: %d) devices with isPaired=true.", ms(), agentDevice.id, mobileDevice.id);
        
        user.activePairingTokens.remove(pairingToken);
        LOG.infof("[%dms] [LOG-JAVA-PAIR-SUCCESS] Removed pairing token. Pairing process complete.", ms());
    }

    public List<Device> findAgentDevicesByUserId(Long userId) {
        LOG.infof("[%dms] [LOG-JAVA-FIND-AGENTS] Finding agent devices for userId: %d", ms(), userId);
        return Device.list("user.id = ?1 and isPaired = true and clientType = ?2", userId, ClientType.AGENT);
    }

    public List<Device> findMobileDevicesByUserId(Long userId) {
        LOG.infof("[%dms] [LOG-JAVA-FIND-MOBILES] Finding mobile devices for userId: %d", ms(), userId);
        return Device.list("user.id = ?1 and isPaired = true and clientType = ?2", userId, ClientType.MOBILE);
    }
    
    @Transactional
    public Device updateDeviceName(Long userId, Long deviceId, String newName) {
        LOG.infof("[%dms] [LOG-JAVA-UPDATE-NAME-START] Updating device name for deviceId: %d", ms(), deviceId);
        Device device = Device.findById(deviceId);
        if (device == null || !device.user.id.equals(userId)) {
            LOG.warnf("[%dms] [LOG-JAVA-UPDATE-NAME-FAIL] Device not found or user mismatch. Throwing NotFoundException.", ms());
            throw new NotFoundException("Device not found or access denied.");
        }
        device.name = newName;
        device.persist();
        LOG.infof("[%dms] [LOG-JAVA-UPDATE-NAME-SUCCESS] Device name updated and persisted.", ms());
        return device;
    }

    @Transactional
    public void deleteDevice(Long userId, Long deviceId) {
        LOG.infof("[%dms] [LOG-JAVA-DELETE-START] Deleting device for deviceId: %d", ms(), deviceId);
        Device deviceToDelete = Device.findById(deviceId);
        if (deviceToDelete != null && deviceToDelete.user.id.equals(userId)) {
            if (deviceToDelete.clientType == ClientType.AGENT) {
                LOG.infof("[%dms] [LOG-JAVA-DELETE-AGENT] Deleting an AGENT device. Also deleting all associated MOBILE devices.", ms());
                Device.delete("user.id = ?1 and clientType = ?2", userId, ClientType.MOBILE);
                deviceToDelete.delete();
            } else if (deviceToDelete.clientType == ClientType.MOBILE) {
                LOG.infof("[%dms] [LOG-JAVA-DELETE-MOBILE] Deleting a MOBILE device.", ms());
                deviceToDelete.delete();
            }
             LOG.infof("[%dms] [LOG-JAVA-DELETE-SUCCESS] Deletion successful.", ms());
        } else {
             LOG.warnf("[%dms] [LOG-JAVA-DELETE-FAIL] Device not found or user mismatch. No deletion performed.", ms());
        }
    }
}