import json
import logging
from concurrent import futures
import grpc
import llm_client 
from protos import orchestrator_pb2, orchestrator_pb2_grpc
from fastapi import FastAPI

logging.basicConfig(level=logging.INFO)
app = FastAPI(root_path="/api")

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "Orchestrator-py gRPC service is running"}

class OrchestratorServicer(orchestrator_pb2_grpc.OrchestratorServiceServicer):
    
    def ProcessCommand(self, request, context):
        client_id = request.clientId
        
        try:
            message = json.loads(request.messageJson)
            user_prompt = message.get("prompt")
            if not user_prompt:
                raise ValueError("'prompt' key not found in messageJson")
        except (json.JSONDecodeError, ValueError) as e:
            error_msg = f"Invalid message format from client {client_id}: {e}"
            logging.error(f"[gRPC Server] {error_msg}")
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details(error_msg)
            return orchestrator_pb2.ProcessResponse()

        logging.info(f"[Gate-0] Received prompt from {client_id}: '{user_prompt}'")
        
        generated_code_json_str = llm_client.generate_code(user_prompt)
        if not generated_code_json_str:
            error_msg = f"LLM failed to generate code for client {client_id}."
            logging.error(f"[gRPC Server] {error_msg}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(error_msg)
            return orchestrator_pb2.ProcessResponse()

        try:
            code_data = json.loads(generated_code_json_str)
            intent = code_data.get("intent")
            code = code_data.get("code")
            if not all([intent, code]):
                raise ValueError("Missing 'intent' or 'code' in LLM response.")
        except (json.JSONDecodeError, ValueError) as e:
            error_msg = f"Invalid JSON from code-gen LLM for {client_id}: {e}"
            logging.error(f"[gRPC Server] {error_msg}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(error_msg)
            return orchestrator_pb2.ProcessResponse()

        logging.info(f"[Gate-1] Performing security analysis for {client_id}...")

        analysis_json_str = llm_client.analyze_code_with_llm(intent=intent, code=code)
        if not analysis_json_str:
            error_msg = f"Security LLM failed to analyze code for client {client_id}."
            logging.error(f"[gRPC Server] {error_msg}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(error_msg)
            return orchestrator_pb2.ProcessResponse()

        try:
            analysis_data = json.loads(analysis_json_str)
            is_compatible = analysis_data.get("is_intent_compatible")
            is_secure = analysis_data.get("is_secure")
            if not isinstance(is_compatible, bool) or not isinstance(is_secure, bool):
                 raise ValueError("Missing or non-boolean security flags in analysis response.")
        except (json.JSONDecodeError, ValueError) as e:
            error_msg = f"Invalid JSON from security LLM for {client_id}: {e}"
            logging.error(f"[gRPC Server] {error_msg}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(error_msg)
            return orchestrator_pb2.ProcessResponse()
        
        if not is_compatible or not is_secure:
            error_message = f"Security Gate-1 Blocked: Intent Compatible={is_compatible}, Secure={is_secure}"
            logging.warning(f"[gRPC Server] ❌ {error_message} for client {client_id}")
            
            error_response_payload = {
                "intent": "Action Blocked by Security Gate 1",
                "code": f"print('{error_message}')"
            }
            return orchestrator_pb2.ProcessResponse(
                status="GATE1_BLOCKED",
                message=json.dumps(error_response_payload)
            )

        logging.info(f"[gRPC Server] ✅ Gate-1 Analysis passed for {client_id}. Forwarding code.")

        return orchestrator_pb2.ProcessResponse(
            status="CODE_GENERATED_AND_VERIFIED",
            message=generated_code_json_str
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