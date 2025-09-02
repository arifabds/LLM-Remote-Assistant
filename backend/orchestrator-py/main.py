from fastapi import FastAPI, Request
from pydantic import BaseModel
import requests 
import json
import logging
import llm_client
import grpc
from concurrent import futures
from protos import orchestrator_pb2
from protos import orchestrator_pb2_grpc


class CommandMessage(BaseModel):
    type: str
    prompt: str

class ProcessRequest(BaseModel):
    clientId: str
    message: CommandMessage

app = FastAPI(root_path="/api")
logging.basicConfig(level=logging.INFO)

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
    
class OrchestratorServicer(orchestrator_pb2_grpc.OrchestratorServiceServicer):
    
    def ProcessCommand(self, request, context):
        client_id = request.clientId
        
        try:
            message = json.loads(request.messageJson)
            user_prompt = message.get("prompt")
            if not user_prompt:
                raise ValueError("'prompt' key not found in messageJson")
        except (json.JSONDecodeError, ValueError) as e:
            logging.error(f"[gRPC Server] Invalid message format from client {client_id}: {e}")
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details(f"Invalid message format: {e}")
            return orchestrator_pb2.ProcessResponse()

        logging.info(f"[gRPC Server] Received prompt from client {client_id}: '{user_prompt}'")
        
        generated_content = llm_client.generate_code(user_prompt)

        if not generated_content:
            logging.error(f"[gRPC Server] LLM failed to generate code for client {client_id}.")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details("LLM failed to generate code.")
            return orchestrator_pb2.ProcessResponse()

        logging.info(f"[gRPC Server] Generated code for client {client_id}. Forwarding back.")

        return orchestrator_pb2.ProcessResponse(
            status="CODE_GENERATED",
            message=generated_content
        )


def serve_grpc():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    orchestrator_pb2_grpc.add_OrchestratorServiceServicer_to_server(OrchestratorServicer(), server)
    server.add_insecure_port('[::]:50051')
    logging.info("Starting gRPC server on port 50051")
    server.start()
    server.wait_for_termination()

if __name__ == "__main__":
    serve_grpc()