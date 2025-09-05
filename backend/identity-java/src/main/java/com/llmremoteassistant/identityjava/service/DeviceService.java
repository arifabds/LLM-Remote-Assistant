package com.llmremoteassistant.identityjava.service;

import com.llmremoteassistant.identityjava.model.Device;
import com.llmremoteassistant.identityjava.model.DeviceStatus;
import com.llmremoteassistant.identityjava.model.DeviceType;
import com.llmremoteassistant.identityjava.model.User;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.NotFoundException;

@ApplicationScoped
public class DeviceService {

    @Transactional
    public void pairDevice(Long userId, String deviceName) {
        // pairing token validation in B
        
        User user = User.findById(userId);
        if (user == null) {
            throw new NotFoundException("User not found");
        }

        Device newDevice = new Device();
        newDevice.name = deviceName;
        newDevice.user = user;
        newDevice.status = DeviceStatus.OFFLINE;
        newDevice.type = DeviceType.UNKNOWN; 
        
        newDevice.persist();
    }
}