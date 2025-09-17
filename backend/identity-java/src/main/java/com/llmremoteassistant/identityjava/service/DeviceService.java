package com.llmremoteassistant.identityjava.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.llmremoteassistant.identityjava.model.*;
import com.llmremoteassistant.identityjava.rest.DeviceDTO;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@ApplicationScoped
public class DeviceService {

    private static final Logger LOG = Logger.getLogger(DeviceService.class);
    private static final Instant startTime = Instant.now();
    private long ms() { return Duration.between(startTime, Instant.now()).toMillis(); }

    @ConfigProperty(name = "gateway.service.url")
    String gatewayServiceUrl;

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public List<Device> findMobileDevicesByUserId(Long userId) {
        LOG.infof("[%dms] [LOG-JAVA-FIND-MOBILES] Finding mobile devices for userId: %d", ms(), userId);
        return Device.list("user.id = ?1 and isPaired = true and clientType = ?2", userId, ClientType.MOBILE);
    }

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
        notifyGatewayOfPairingComplete(user.id);
    }

    @Transactional
    public DeviceDTO updateDeviceName(Long userId, Long deviceId, String newName) {
        LOG.infof("[%dms] [LOG-JAVA-UPDATE-NAME-START] Updating device name for deviceId: %d", ms(), deviceId);
        Device device = Device.findById(deviceId);
        if (device == null || !device.user.id.equals(userId)) {
            LOG.warnf("[%dms] [LOG-JAVA-UPDATE-NAME-FAIL] Device not found or user mismatch. Throwing NotFoundException.", ms());
            throw new NotFoundException("Device not found or access denied.");
        }
        device.name = newName;
        device.persist();
        LOG.infof("[%dms] [LOG-JAVA-UPDATE-NAME-SUCCESS] Device name updated and persisted.", ms());

        LOG.infof("[%dms] [LOG-P.13.1.1-ENRICH] Enriching updated device with live status before returning.", ms());
        Set<String> onlineDeviceIds = getOnlineAgentDeviceIds(userId);
        DeviceStatus currentStatus = onlineDeviceIds.contains(device.deviceId) ? DeviceStatus.ONLINE : DeviceStatus.OFFLINE;

        return new DeviceDTO(
            device.id,
            device.deviceId,
            device.name,
            device.clientType,
            currentStatus,
            device.pairedAt
        );
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

    private Set<String> getOnlineAgentDeviceIds(Long userId) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(gatewayServiceUrl + "/internal/status/user/" + userId))
                    .timeout(Duration.ofSeconds(2))
                    .GET()
                    .build();
            
            LOG.infof("[%dms] [LOG-P.1.2-JAVA-HTTP-REQ] Sending request to Go Gateway to get online agents for userId: %d", ms(), userId);
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            
            if (response.statusCode() == 200 && response.body() != null) {
                List<String> deviceIds = objectMapper.readValue(response.body(), new TypeReference<List<String>>() {});
                
                if (deviceIds == null) {
                    LOG.warnf("[%dms] [LOG-PPRIME.1.1-NULL-BODY] Go Gateway returned a null list. Assuming no agents are online.", ms());
                    return Collections.emptySet();
                }

                LOG.infof("[%dms] [LOG-P.1.2-JAVA-HTTP-RESP] Go Gateway returned %d online agents.", ms(), deviceIds.size());
                return Set.copyOf(deviceIds);

            } else {
                 LOG.warnf("[%dms] [LOG-P.1.2-JAVA-HTTP-FAIL] Go Gateway returned non-200 status: %d or null body.", ms(), response.statusCode());
            }
        } catch (Exception e) {
             LOG.errorf(e, "[%dms] [LOG-PPRIME.1.1-HTTP-EXC] Exception while calling Go Gateway. Returning empty set.", ms());
        }
        return Collections.emptySet();
    }
 
    public List<DeviceDTO> findAgentDevicesByUserIdAndEnrichStatus(Long userId) {
         LOG.infof("[%dms] [LOG-P.1.2-JAVA-FIND-AGENTS] Finding agent devices for userId: %d and enriching with live status.", ms(), userId);

         List<Device> devicesFromDb = Device.list("user.id = ?1 and isPaired = true and clientType = ?2", userId, ClientType.AGENT);
         if (devicesFromDb.isEmpty()) {
             return Collections.emptyList();
         }
         
         Set<String> onlineDeviceIds = getOnlineAgentDeviceIds(userId);
 
         return devicesFromDb.stream()
                 .map(device -> {
                     DeviceStatus status = onlineDeviceIds.contains(device.deviceId) ? DeviceStatus.ONLINE : DeviceStatus.OFFLINE;
                     return new DeviceDTO(
                             device.id,
                             device.deviceId,
                             device.name,
                             device.clientType,
                             status,
                             device.pairedAt);
                 })
                 .collect(Collectors.toList());
    }
    private void notifyGatewayOfPairingComplete(Long userId) {
        try {
            String requestBody = objectMapper.writeValueAsString(Map.of("userId", userId.toString()));
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(gatewayServiceUrl + "/internal/notify-pairing-complete"))
                    .timeout(Duration.ofSeconds(2))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();
            
            LOG.infof("[%dms] [LOG-P.2.1-JAVA-NOTIFY-SEND] Notifying Go Gateway that pairing is complete for userId: %d", ms(), userId);
            httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenAccept(response -> {
                    LOG.infof("[%dms] [LOG-P.2.1-JAVA-NOTIFY-RESP] Go Gateway notification response status: %d", ms(), response.statusCode());
                });

        } catch (Exception e) {
            LOG.errorf(e, "[%dms] [LOG-P.2.1-JAVA-NOTIFY-EXC] Exception while notifying Go Gateway of pairing completion.", ms());
        }
    }
 
 }