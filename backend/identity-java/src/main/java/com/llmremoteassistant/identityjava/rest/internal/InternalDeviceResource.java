package com.llmremoteassistant.identityjava.rest.internal;

import com.llmremoteassistant.identityjava.model.DeviceStatus;
import com.llmremoteassistant.identityjava.service.DeviceService;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path("/internal/devices")
public class InternalDeviceResource {

    @Inject
    DeviceService deviceService;

    @POST
    @Path("/{deviceId}/status")
    @Consumes(MediaType.TEXT_PLAIN)
    public Response updateDeviceStatus(@PathParam("deviceId") String deviceId, String status) {
        try {
            DeviceStatus deviceStatus = DeviceStatus.valueOf(status.toUpperCase());
            deviceService.updateDeviceStatusByDeviceId(deviceId, deviceStatus);
            return Response.ok().build();
        } catch (IllegalArgumentException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("Invalid status value. Must be ONLINE or OFFLINE.")
                    .build();
        }
    }
}