package com.llmremoteassistant.identityjava.rest;

import com.llmremoteassistant.identityjava.service.DeviceService;
import io.quarkus.security.Authenticated;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;

@Path("/api/devices")
@Authenticated
public class DeviceResource {

    @Inject
    DeviceService deviceService;

    @Inject
    JsonWebToken jwt;

    @POST
    @Path("/pair")
    @Consumes(MediaType.APPLICATION_JSON)
    public Response pairDevice(PairDeviceRequest request) {
        Long userId = Long.parseLong(jwt.getSubject());
        
        deviceService.pairDevice(userId, request.deviceName());
        
        return Response.status(Response.Status.CREATED).build();
    }
}