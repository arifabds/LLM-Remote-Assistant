import json
import logging
from concurrent import futures
import grpc
import llm_client 
from protos import orchestrator_pb2, orchestrator_pb2_grpc
from fastapi import FastAPI
import requests
from contextlib import asynccontextmanager

grpc_server = None

logging.basicConfig(level=logging.INFO)

@asynccontextmanager
async def lifespan(app: FastAPI):
    global grpc_server
    grpc_server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    
    orchestrator_pb2_grpc.add_OrchestratorServiceServicer_to_server(OrchestratorServicer(), grpc_server)
    
    grpc_server.add_insecure_port('[::]:50051')
    grpc_server.start()
    logging.info("gRPC server started on port 50051")
    
    yield
    
    grpc_server.stop(0)
    logging.info("gRPC server stopped.")

app = FastAPI(root_path="/api", lifespan=lifespan)

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "Orchestrator-py FastAPI & gRPC services are running"}

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

    def HandleConfirmation(self, request, context):
        client_id = request.clientId
        intent = request.intent
        approved = request.approved
        
        logging.info(f"[gRPC Conf] Received confirmation from {client_id} for intent '{intent}'. Approved: {approved}")
        
        pending_command = self.pending_confirmations.pop(client_id, None)
        
        if not pending_command:
            logging.warning(f"[gRPC Conf] No pending command found for client {client_id}. Ignoring.")
            return orchestrator_pb2.ConfirmationResponse(status="NO_PENDING_COMMAND")

        if pending_command["intent"] != intent:
            logging.error(f"[gRPC Conf] Intent mismatch for {client_id}. Stored: '{pending_command['intent']}', Received: '{intent}'. Aborting.")
            return orchestrator_pb2.ConfirmationResponse(status="INTENT_MISMATCH")

        if approved:
            logging.info(f"[gRPC Conf] ✅ Command approved. Sending to agent for client {client_id}.")
            
            try:
                payload_to_agent = json.dumps(pending_command)
                go_url = "http://gateway-go:8081/internal/send-to-agent"
                response = requests.post(go_url, json={"userId": client_id, "message": payload_to_agent}, timeout=5)
                response.raise_for_status()
            except requests.exceptions.RequestException as e:
                logging.error(f"[gRPC Conf] Failed to send approved command to Go Gateway for {client_id}: {e}")
                # TODO: feedback to mobile client
        else:
            logging.info(f"[gRPC Conf] ❌ Command denied by user {client_id}.")
            # TODO: feedback process canceled or smth.
        
        return orchestrator_pb2.ConfirmationResponse(status="OK")        

