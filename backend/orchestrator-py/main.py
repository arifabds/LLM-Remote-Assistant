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

    def _send_status_update(self, stage, message, command_id):
        payload = {
            "type": "status_update",
            "stage": stage,
            "message": message
        }
        return orchestrator_pb2.ProcessResponse(
            status="STATUS_UPDATE",
            message=json.dumps(payload),
            commandId=command_id
        )
    
    def ProcessCommand(self, request, context):
        client_id = request.clientId
        command_id = request.commandId

        def command_processor_flow():
            try:
                message = json.loads(request.messageJson)
                user_prompt = message.get("prompt")
                if not user_prompt:
                    raise ValueError("'prompt' key not found in messageJson")
            except (json.JSONDecodeError, ValueError) as e:
                error_msg = f"Invalid message format from client {client_id}: {e}"
                logging.error(f"[gRPC Server] {error_msg}")
                return

            # --- Stage 1: Gate-0 Started ---
            logging.info(f"[Gate-0] Analyzing prompt from {client_id} (commandId: {command_id}): '{user_prompt}'")
            yield self._send_status_update("generating_code", "The assistant understands your command and is generating the code...", command_id)

            gate0_json_str = llm_client.generate_code(user_prompt)
            if not gate0_json_str:
                logging.error(f"[gRPC Server] Gate-0 LLM failed for {client_id} (commandId: {command_id}).")
                yield self._send_status_update("error", "The assistant could not respond. Please try again.", command_id)
                return

            try:
                gate0_data = json.loads(gate0_json_str)
                is_valid = gate0_data.get("is_valid_request")
                is_safe = gate0_data.get("is_safe_to_generate")
                
                if not (is_valid and is_safe):
                    reason = gate0_data.get("reason", "No reason provided.")
                    logging.warning(f"[gRPC Server] ❌ Gate-0 Blocked for {client_id} (commandId: {command_id}): {reason}")
                    error_payload = { "type": "execution_result", "status": "error", "output": f"Request rejected: {reason}" }
                    yield orchestrator_pb2.ProcessResponse(status="GATE0_BLOCKED", message=json.dumps(error_payload), commandId=command_id)
                    return

                logging.info(f"[gRPC Server] ✅ Gate-0 Passed for {client_id} (commandId: {command_id}).")
                intent = gate0_data.get("intent")
                code = gate0_data.get("code")
                if not all([intent, code]):
                    raise ValueError("Missing 'intent' or 'code' in Gate-0 response.")

            except (json.JSONDecodeError, ValueError) as e:
                logging.error(f"[gRPC Server] Invalid JSON from Gate-0 for {client_id} (commandId: {command_id}): {e}")
                yield self._send_status_update("error", "The assistant generated an invalid response.", command_id)
                return
            
            # --- Stage 2: Gate-1 Started ---
            logging.info(f"[Gate-1] Security analysis for {client_id} (commandId: {command_id})...")
            yield self._send_status_update("analyzing_security", "The generated code is being checked for security...", command_id)

            analysis_json_str = llm_client.analyze_code_with_llm(intent=intent, code=code)
            if not analysis_json_str:
                logging.error(f"[gRPC Server] Security LLM failed for {client_id} (commandId: {command_id}).")
                yield self._send_status_update("error", "An error occurred during the security analysis.", command_id)
                return

            try:
                analysis_data = json.loads(analysis_json_str)
                security_level = analysis_data.get("security_level")
                explanation = analysis_data.get("explanation", "No explanation provided.")

                if security_level == "BLOCK":
                    logging.warning(f"[gRPC Server] ❌ Gate-1 Blocked for {client_id} (commandId: {command_id}): {explanation}")
                    error_payload = {"type": "execution_result", "status": "error", "output": f"Action blocked: {explanation}"}
                    yield orchestrator_pb2.ProcessResponse(status="GATE1_BLOCKED", message=json.dumps(error_payload), commandId=command_id)
                    return

                if security_level == "CONFIRM":
                    self.pending_confirmations[client_id] = {"intent": intent, "code": code, "commandId": command_id}
                    yield self._send_status_update("waiting_confirmation", "Waiting for confirmation from your mobile device for this action...", command_id)
                    confirm_payload = {"type": "confirmation_required", "intent": intent, "explanation": explanation}
                    yield orchestrator_pb2.ProcessResponse(status="CONFIRMATION_REQUIRED", message=json.dumps(confirm_payload), commandId=command_id)
                    return

                logging.info(f"[gRPC Server] ✅ Gate-1 Passed (ALLOW) for {client_id} (commandId: {command_id}).")
                yield self._send_status_update("sending_to_agent", "The code has been approved and is being sent to your computer...", command_id)
                
                final_payload_to_agent = {"type": "code_package", "intent": intent, "code": code}
                yield orchestrator_pb2.ProcessResponse(status="CODE_GENERATED_AND_VERIFIED", message=json.dumps(final_payload_to_agent), commandId=command_id)

            except (json.JSONDecodeError, ValueError) as e:
                logging.error(f"[gRPC Server] Invalid JSON from security LLM for {client_id} (commandId: {command_id}): {e}")
                yield self._send_status_update("error", "The security analysis response could not be understood.", command_id)
                return
        
        return command_processor_flow()

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
            logging.error(f"[gRPC Conf] Intent mismatch for {client_id}.")
            return orchestrator_pb2.ConfirmationResponse(status="INTENT_MISMATCH")

        if approved:
            logging.info(f"[gRPC Conf] ✅ Command approved. Sending to agent for client {client_id}.")
            try:
                payload_data = {"type": "code_package", "intent": pending_command["intent"], "code": pending_command["code"]}
                payload_to_agent = json.dumps(payload_data)
                go_url = "http://gateway-go:8081/internal/send-to-agent"
                response = requests.post(go_url, json={"userId": client_id, "message": payload_to_agent}, timeout=5)
                response.raise_for_status()
            except requests.exceptions.RequestException as e:
                logging.error(f"[gRPC Conf] Failed to send approved command to Go Gateway for {client_id}: {e}")
        else:
            logging.info(f"[gRPC Conf] ❌ Command denied by user {client_id}.")
            try:
                cancellation_report = {"type": "execution_result", "status": "cancelled", "output": "The operation was cancelled by the user."}
                payload_to_mobile = json.dumps(cancellation_report)
                go_url = "http://gateway-go:8081/internal/send-to-mobile"
                response = requests.post(go_url, json={"userId": client_id, "message": payload_to_mobile}, timeout=5)
                response.raise_for_status()
            except requests.exceptions.RequestException as e:
                logging.error(f"[gRPC Conf] Failed to send cancellation report to Go Gateway for {client_id}: {e}")
        
        return orchestrator_pb2.ConfirmationResponse(status="OK")