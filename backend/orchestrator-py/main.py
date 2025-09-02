from fastapi import FastAPI, Request
from pydantic import BaseModel
import requests 
import json
import logging
import llm_client


class CommandMessage(BaseModel):
    type: str
    prompt: str

class ProcessRequest(BaseModel):
    clientId: str
    message: CommandMessage

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
    user_prompt = request.message.prompt
    logging.info(f"[Orchestrator] User prompt: '{user_prompt}'")
    
    generated_content = llm_client.generate_code(user_prompt)

    if not generated_content:
        logging.error(f"[Orchestrator] LLM failed to generate code for prompt: '{user_prompt}'")
        return {"status": "error_llm_failed"}

    logging.info(f"[Orchestrator] LLM generated content: {generated_content}")

    try:
        payload_to_send = json.loads(generated_content)
    except json.JSONDecodeError:
        logging.error(f"[Orchestrator] LLM output was not valid JSON: {generated_content}")
        return {"status": "error_llm_invalid_json"}

    go_service_url = "http://gateway-go:8081/internal/send-message"
    go_request_body = {
        "clientId": request.clientId, 
        "payload": payload_to_send    
    }
    
    try:
        response = requests.post(go_service_url, json=go_request_body, timeout=5)
        response.raise_for_status() 
        logging.info(f"[Orchestrator] Successfully forwarded generated code to Go for client {request.clientId}")
        
        return {"status": "processing_complete_and_forwarded"}

    except requests.exceptions.RequestException as e:
        logging.error(f"[Orchestrator] FAILED to forward response to Go: {e}")
        return {"status": "error_failed_to_forward_to_go"}

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