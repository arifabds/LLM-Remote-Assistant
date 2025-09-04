import asyncio
import websockets
import json
import io
import contextlib
import requests
import logging

import native_core
from config import USERNAME, PASSWORD, IDENTITY_SERVICE_URL, WEBSOCKET_URL

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def get_jwt_token() -> str | None:
    login_url = f"{IDENTITY_SERVICE_URL}/api/auth/login"
    logging.info(f"Attempting to log in as '{USERNAME}' at {login_url}")
    try:
        response = requests.post(login_url, json={"username": USERNAME, "password": PASSWORD}, timeout=5)
        
        if response.status_code == 200:
            token = response.text
            logging.info("Successfully logged in and received JWT token.")
            return token
        else:
            logging.error(f"Failed to log in. Status: {response.status_code}, Body: {response.text}")
            return None
    except requests.exceptions.RequestException as e:
        logging.error(f"Error connecting to identity service: {e}")
        return None

async def listen_for_code(websocket):
    logging.info("Reply listener has started. Waiting for commands...")
    async for message_str in websocket:
        logging.info(f"<-- Received reply from server: {message_str}")
        try:
            data = json.loads(message_str)
            intent = data.get("intent")
            code_to_execute = data.get("code")

            if intent and code_to_execute:
                logging.info(f"   [Action] Intent: '{intent}'")
                
                logging.info("   [Gate-2] Analyzing code with native security engine...")
                is_safe = native_core.analyze_code(code_to_execute)

                report = {}
                if is_safe:
                    logging.info("   [Gate-2] ✅ Code is safe. Executing...")
                    execution_successful = True
                    output = ""
                    try:
                        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
                            exec(code_to_execute)
                            output = buf.getvalue()
                        logging.info("   [Execution] Code executed successfully.")
                    except Exception as e:
                        logging.error(f"   [Execution] ❌ Error during code execution: {e}")
                        output = f"Error: {e}"
                        execution_successful = False
                    
                    report = {"type": "execution_result", "status": "success" if execution_successful else "error", "output": output.strip()}
                else:
                    logging.warning("   [Gate-2] ❌ DANGEROUS CODE DETECTED! Execution aborted.")
                    report = {"type": "execution_result", "status": "error", "output": "Security violation: Blocked by agent's Gate-2."}
                
                logging.info("   [Reporting] Sending execution result back to server...")
                await websocket.send(json.dumps(report))
            else:
                logging.info(f"   [Info] Received non-actionable message: {data}")

        except json.JSONDecodeError:
            logging.warning("Received a message that is not valid JSON.")
        except Exception as e:
            logging.error(f"An unexpected error occurred in listener: {e}")

async def connect_and_listen():
    jwt_token = get_jwt_token()
    if not jwt_token:
        logging.error("Could not retrieve JWT token. Agent will not start.")
        return

    uri = f"{WEBSOCKET_URL}?clientType=agent"
    headers = {"Authorization": f"Bearer {jwt_token}"}
    
    logging.info(f"Attempting to connect to {uri}")
    
    while True:
        try:
            async with websockets.connect(uri, extra_headers=headers) as websocket:
                logging.info("Successfully connected to the server!")
                await listen_for_code(websocket)
        except websockets.exceptions.ConnectionClosed as e:
            logging.warning(f"Connection closed: {e}. Reconnecting in 10 seconds...")
        except Exception as e:
            logging.error(f"Connection error: {e}. Reconnecting in 10 seconds...")
        
        await asyncio.sleep(10)

if __name__ == "__main__":
    try:
        asyncio.run(connect_and_listen())
    except KeyboardInterrupt:
        logging.info("Agent stopped by user.")