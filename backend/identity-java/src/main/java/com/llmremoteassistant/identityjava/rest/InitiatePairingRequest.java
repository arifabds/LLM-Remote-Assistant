package com.llmremoteassistant.identityjava.rest;

public record InitiatePairingRequest(String pairingToken, String agentDeviceId, String agentDeviceName) {}