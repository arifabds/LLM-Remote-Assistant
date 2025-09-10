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

    pending_confirmations = {}
    
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

        # Gate-0
        logging.info(f"[Gate-0] Analyzing prompt from {client_id}: '{user_prompt}'")
        
        gate0_json_str = llm_client.generate_code(user_prompt)
        if not gate0_json_str:
            error_msg = f"Gate-0 LLM failed to generate a response for client {client_id}."
            logging.error(f"[gRPC Server] {error_msg}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(error_msg)
            return orchestrator_pb2.ProcessResponse()

        try:
            gate0_data = json.loads(gate0_json_str)
            is_valid = gate0_data.get("is_valid_request")
            is_safe = gate0_data.get("is_safe_to_generate")
            
            if not isinstance(is_valid, bool) or not isinstance(is_safe, bool):
                 raise ValueError("Missing or non-boolean flags in Gate-0 response.")
            
            if not is_valid or not is_safe:
                reason = gate0_data.get("reason", "No reason provided.")
                error_message = f"Gate-0 Blocked: {reason}"
                logging.warning(f"[gRPC Server] ❌ {error_message} for client {client_id}")
                
                error_response_payload = {
                    "type": "execution_result",
                    "status": "error",
                    "output": f"Request rejected: {reason}"
                }
                return orchestrator_pb2.ProcessResponse(
                    status="GATE0_BLOCKED",
                    message=json.dumps(error_response_payload)
                )

            # --- Gate-0 Successful ---
            logging.info(f"[gRPC Server] ✅ Gate-0 Analysis passed for {client_id}.")
            intent = gate0_data.get("intent")
            code = gate0_data.get("code")
            if not all([intent, code]):
                raise ValueError("Missing 'intent' or 'code' in Gate-0 response despite passing checks.")

        except (json.JSONDecodeError, ValueError) as e:
            error_msg = f"Invalid JSON from Gate-0 LLM for {client_id}: {e}\nRaw Response: {gate0_json_str}"
            logging.error(f"[gRPC Server] {error_msg}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(error_msg)
            return orchestrator_pb2.ProcessResponse()
        
        # Gate-1
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
            security_level = analysis_data.get("security_level")
            explanation = analysis_data.get("explanation", "No explanation provided.")

            if not isinstance(is_compatible, bool) or security_level not in ["ALLOW", "BLOCK", "CONFIRM"]:
                 raise ValueError("Invalid or missing fields in Gate-1 response.")
            
            # --- Gate-1 Judge
            if not is_compatible:
                logging.warning(f"[gRPC Server] ❌ Gate-1 Blocked (Incompatible Intent) for {client_id}: {explanation}")
                error_payload = {"type": "execution_result", "status": "error", "output": f"Action blocked: Code does not match intent. {explanation}"}
                return orchestrator_pb2.ProcessResponse(status="GATE1_BLOCKED", message=json.dumps(error_payload))

            if security_level == "BLOCK":
                logging.warning(f"[gRPC Server] ❌ Gate-1 Blocked (Malicious Code) for {client_id}: {explanation}")
                error_payload = {"type": "execution_result", "status": "error", "output": f"Action blocked: Malicious code detected. {explanation}"}
                return orchestrator_pb2.ProcessResponse(status="GATE1_BLOCKED", message=json.dumps(error_payload))

            if security_level == "CONFIRM":

                self.pending_confirmations[client_id] = {"intent": intent, "code": code}
                logging.info(f"[gRPC Server] Stored command for {client_id} pending confirmation.")

                logging.info(f"[gRPC Server] 🟡 Gate-1 requires confirmation for {client_id}: {explanation}")
                confirm_payload = {
                    "type": "confirmation_required", 
                    "intent": intent, 
                    "explanation": explanation
                }
                return orchestrator_pb2.ProcessResponse(
                    status="CONFIRMATION_REQUIRED", 
                    message=json.dumps(confirm_payload)
                )

            # --- Gate-1 Successful
            logging.info(f"[gRPC Server] ✅ Gate-1 Analysis passed (ALLOW) for {client_id}. Forwarding code.")
            final_payload_to_agent = json.dumps({"intent": intent, "code": code})
            return orchestrator_pb2.ProcessResponse(
                status="CODE_GENERATED_AND_VERIFIED",
                message=final_payload_to_agent
            )

        except (json.JSONDecodeError, ValueError) as e:
            error_msg = f"Invalid JSON from security LLM for {client_id}: {e}"
            logging.error(f"[gRPC Server] {error_msg}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(error_msg)
            return orchestrator_pb2.ProcessResponse()

def serve_grpc():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    orchestrator_pb2_grpc.add_OrchestratorServiceServicer_to_server(OrchestratorServicer(), server)
    server.add_insecure_port('[::]:50051')
    logging.info("Starting gRPC server on port 50051")
    server.start()
    server.wait_for_termination()

if __name__ == "__main__":
    serve_grpc()