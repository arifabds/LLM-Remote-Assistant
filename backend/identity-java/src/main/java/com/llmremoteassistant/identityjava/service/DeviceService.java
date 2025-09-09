package com.llmremoteassistant.identityjava.service;

import com.llmremoteassistant.identityjava.model.*;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import java.util.List;

@ApplicationScoped
public class DeviceService {

    @Transactional
    public void initiatePairing(Long userId, String pairingToken) {
        User user = User.findById(userId);
        if (user == null) {
            throw new NotFoundException("User not found for ID: " + userId);
        }
        user.activePairingTokens.add(pairingToken);
        user.persist();
    }

    @Transactional
    public void pairMobileDevice(Long mobileUserId, String pairingToken, String mobileDeviceName) {
        List<User> users = User.list("?1 MEMBER OF activePairingTokens", pairingToken);
        
        if (users.isEmpty()) {
            throw new BadRequestException("Invalid or expired pairing token.");
        }
        User agentUser = users.get(0);

        if (!agentUser.id.equals(mobileUserId)) {
            throw new BadRequestException("User ID mismatch. Pairing request is not valid.");
        }

        Device mobileDevice = new Device();
        mobileDevice.name = mobileDeviceName;
        mobileDevice.user = agentUser;
        mobileDevice.clientType = ClientType.MOBILE;
        mobileDevice.osType = OsType.UNKNOWN;
        mobileDevice.status = DeviceStatus.ONLINE;
        mobileDevice.persist();
        
        agentUser.activePairingTokens.remove(pairingToken);
    }
}