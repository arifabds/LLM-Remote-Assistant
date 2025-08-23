from fastapi import FastAPI, Request
import requests 
import json

app = FastAPI(root_path="/api")

@app.get("/")
def read_root():
    return {"message": "Orchestrator-py is running"}

@app.get("/health")
def health_check():
    return {"status": "ok"}

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