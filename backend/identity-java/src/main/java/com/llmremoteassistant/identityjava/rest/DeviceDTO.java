package com.llmremoteassistant.identityjava.rest;

import com.llmremoteassistant.identityjava.model.ClientType;
import com.llmremoteassistant.identityjava.model.Device;
import com.llmremoteassistant.identityjava.model.DeviceStatus;

import java.time.LocalDateTime;

public record DeviceDTO(
        Long id,
        String deviceId,
        String name,
        ClientType clientType,
        DeviceStatus status,
        LocalDateTime pairedAt) {

    public static DeviceDTO fromEntity(Device device) {
        return new DeviceDTO(
                device.id,
                device.deviceId,
                device.name,
                device.clientType,
                device.status,
                device.pairedAt);
    }
}