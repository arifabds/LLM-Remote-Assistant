from fastapi import FastAPI, Request
from pydantic import BaseModel
import requests 
import json
import logging

# Go request's body
class ProcessRequest(BaseModel):
    clientId: str
    message: dict

app = FastAPI(root_path="/api")

@app.get("/")
def read_root():
    return {"message": "Orchestrator-py is running"}

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.post("/v1/process")
def process_command(request: ProcessRequest):
    logging.info(f"[Orchestrator] Received command from client {request.clientId}")
    logging.info(f"[Orchestrator] Message content: {request.message}")

    response_payload = {
        "type": "acknowledged",
        "original_command": request.message,
        "response": f"Command received from {request.clientId}. Acknowledged by Python."
    }

    go_service_url = "http://gateway-go:8081/internal/send-message"
    go_request_body = {
        "clientId": request.clientId,
        "payload": response_payload
    }
    
    try:
        response = requests.post(go_service_url, json=go_request_body, timeout=5)
        response.raise_for_status()
        logging.info(f"[Orchestrator] Successfully forwarded response to Go for client {request.clientId}")
    except requests.exceptions.RequestException as e:
        logging.error(f"[Orchestrator] FAILED to forward response to Go: {e}")

    return {"status": "processing_started"}

@app.post("/internal-proxy-test")
async def internal_proxy_test(request: Request):
    try:
        body = await request.json()
        client_id = body.get("clientId")
        payload = body.get("payload")

        if not client_id or not payload:
            return {"error": "clientId and payload are required"}

        go_service_url = "http://gateway-go:8081/internal/send-message"
        go_request_body = {
            "clientId": client_id,
            "payload": payload
        }
        
        response = requests.post(go_service_url, json=go_request_body, timeout=5)
        response.raise_for_status() 
            
        return {"status": "success", "response_from_go": response.text}
    except requests.exceptions.RequestException as e:
        return {"status": "error", "message": str(e)}
    except json.JSONDecodeError:
        return {"error": "Invalid JSON body"}