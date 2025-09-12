package com.llmremoteassistant.identityjava.rest;

public record PairDeviceRequest(String pairingToken, String mobileDeviceId, String mobileDeviceName) {}