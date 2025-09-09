// backend/identity-java/src/main/java/com/llmremoteassistant/identityjava/rest/DeviceResource.java

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
    @Path("/initiate-pairing")
    @Consumes(MediaType.TEXT_PLAIN)
    public Response initiatePairing(String pairingToken) {
        Long userId = Long.parseLong(jwt.getSubject());
        deviceService.initiatePairing(userId, pairingToken);
        return Response.ok().build();
    }

    @POST
    @Path("/pair")
    @Consumes(MediaType.APPLICATION_JSON)
    public Response pairDevice(PairDeviceRequest request) {
        Long userId = Long.parseLong(jwt.getSubject());
        
        deviceService.pairMobileDevice(userId, request.pairingToken(), request.mobileDeviceName());
        
        return Response.status(Response.Status.CREATED).build();
    }
}