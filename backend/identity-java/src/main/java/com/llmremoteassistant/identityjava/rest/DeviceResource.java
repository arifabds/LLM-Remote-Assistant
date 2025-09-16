package com.llmremoteassistant.identityjava.rest;

import com.llmremoteassistant.identityjava.model.Device;
import com.llmremoteassistant.identityjava.service.DeviceService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.jboss.logging.Logger;

import java.util.List;
import java.util.stream.Collectors;

@Path("/api/devices")
@Authenticated
public class DeviceResource {

    private static final Logger LOG = Logger.getLogger(DeviceResource.class);

    @Inject
    DeviceService deviceService;

    @Inject
    JsonWebToken jwt;

    @POST
    @Path("/initiate-pairing")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.TEXT_PLAIN)
    public String initiatePairing(InitiatePairingRequest request) {
        Long userId = Long.parseLong(jwt.getSubject());
        return deviceService.initiatePairing(userId, request.agentDeviceId(), request.agentDeviceName());
    }

    @POST
    @Path("/pair")
    @Consumes(MediaType.APPLICATION_JSON)
    public Response pairDevice(PairDeviceRequest request) {
        Long userId = Long.parseLong(jwt.getSubject());
        deviceService.pairMobileDevice(userId, request.pairingToken(), request.mobileDeviceId(), request.mobileDeviceName());
        return Response.status(Response.Status.CREATED).build();
    }

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<DeviceDTO> getMyAgentDevices() {
        Long userId = Long.parseLong(jwt.getSubject());
        LOG.infof("[LOG-REST] getMyAgentDevices called for userId: %d. Delegating to service with status enrichment.", userId);
        return deviceService.findAgentDevicesByUserIdAndEnrichStatus(userId);
    }

    @GET
    @Path("/mobiles")
    @Produces(MediaType.APPLICATION_JSON)
    public List<DeviceDTO> getMyMobileDevices() {
        Long userId = Long.parseLong(jwt.getSubject());
        LOG.infof("[LOG-REST] getMyMobileDevices called for userId: %d. Delegating to service (no status enrichment needed for mobiles).", userId);
        return deviceService.findMobileDevicesByUserId(userId)
                .stream()
                .map(DeviceDTO::fromEntity)
                .collect(Collectors.toList());
    }

    @PUT
    @Path("/{id}")
    @Consumes(MediaType.TEXT_PLAIN)
    @Produces(MediaType.APPLICATION_JSON)
    public DeviceDTO updateDeviceName(@PathParam("id") Long deviceId, String newName) {
        Long userId = Long.parseLong(jwt.getSubject());
        Device updatedDevice = deviceService.updateDeviceName(userId, deviceId, newName);
        return DeviceDTO.fromEntity(updatedDevice);
    }

    @DELETE
    @Path("/{id}")
    public Response deleteDevice(@PathParam("id") Long deviceId) {
        Long userId = Long.parseLong(jwt.getSubject());
        deviceService.deleteDevice(userId, deviceId);
        return Response.noContent().build();
    }
}