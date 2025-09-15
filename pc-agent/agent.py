import asyncio
import websockets
import json
import io
import contextlib
import logging
import sys
import threading

from agent_core.gui_communicator import GuiCommunicator
from agent_core.api_client import ApiClient
import native_core
from config import WEBSOCKET_URL

gui = GuiCommunicator()
api = ApiClient()

async def listen_for_code(websocket):
    logging.info("Reply listener has started. Waiting for commands...")
    try:
        async for message_str in websocket:
            logging.info(f"<-- Received reply from server: {message_str}")
            try:
                data = json.loads(message_str)
                gui.send("message_from_server", data)

                msg_type = data.get("type")
                if msg_type == "code_package":
                    code_to_execute = data.get("code")
                    command_id = data.get("commandId", "unknown-id")
                    if not code_to_execute:
                        continue

                    logging.info(f"   [Action] Intent: '{data.get('intent')}' (commandId: {command_id})")
                    is_safe = native_core.analyze_code(code_to_execute)
                    
                    report = {}
                    if is_safe:
                        execution_successful = True
                        output = ""
                        try:
                            with io.StringIO() as buf, contextlib.redirect_stdout(buf):
                                exec(code_to_execute)
                                output = buf.getvalue()
                        except Exception as e:
                            output = f"Error: {e}"
                            execution_successful = False
                        
                        report = {
                            "type": "execution_result", "status": "success" if execution_successful else "error",
                            "output": output.strip(), "commandId": command_id
                        }
                    else:
                        report = {
                            "type": "execution_result", "status": "error",
                            "output": "Security violation: Command blocked by agent's Gate-2.",
                            "commandId": command_id
                        }
                    
                    gui.send("execution_report", report)
                    await websocket.send(json.dumps(report))
            except Exception as e:
                logging.error(f"An unexpected error occurred in listener: {e}", exc_info=True)
    finally:
        gui.send("status_update", {"status": "disconnected", "message": "Lost connection to server."})

async def connect_and_listen(jwt_token: str, device_id: str):
    uri = f"{WEBSOCKET_URL}?clientType=agent&deviceId={device_id}"
    headers = {"Authorization": f"Bearer {jwt_token}"}
    reconnect_delay = 2 
    while True:
        try:
            gui.send("status_update", {"status": "connecting", "message": "Connecting to server..."})
            async with websockets.connect(uri, extra_headers=headers) as websocket:
                gui.send("status_update", {"status": "connected", "message": "Successfully connected to server."})
                reconnect_delay = 2
                await listen_for_code(websocket)
        except Exception as e:
            logging.warning(f"WebSocket connection closed: {e}. Reconnecting in {reconnect_delay}s...")
            gui.send("status_update", {"status": "reconnecting", "message": f"Connection lost. Reconnecting in {reconnect_delay}s..."})
        await asyncio.sleep(reconnect_delay)
        reconnect_delay = min(reconnect_delay * 2, 60)

async def main_async():
    command_queue = asyncio.Queue()
    websocket_task = None
    exit_event = asyncio.Event()
    loop = asyncio.get_running_loop()

    def stdin_reader():
        for line in sys.stdin:
            if not exit_event.is_set():
                loop.call_soon_threadsafe(command_queue.put_nowait, line)

    reader_thread = threading.Thread(target=stdin_reader, daemon=True)
    reader_thread.start()

    gui.send("status_update", {"status": "ready", "message": "Agent is ready for commands."})

    while not exit_event.is_set():
        try:
            command_str = await command_queue.get()
            command = json.loads(command_str.strip())
            action = command.get("action")
            data = command.get("data", {})

            if websocket_task and not websocket_task.done():
                websocket_task.cancel()
                await asyncio.sleep(0.1)

            if action == "login":
                username = data.get("username")
                password = data.get("password")
                jwt_token = api.login(username, password)
                if jwt_token:
                    agent_device_id = data.get("deviceId")
                    gui.send("login_success", {"message": "Login successful."})
                    websocket_task = asyncio.create_task(connect_and_listen(jwt_token, agent_device_id))
                else:
                    gui.send("login_failed", {"error": "Invalid username or password from API."})

            elif action == "auto_login_with_token":
                jwt_token = data.get("token")
                if jwt_token:
                    agent_device_id = data.get("deviceId")
                    gui.send("login_success", {"message": "Auto-login with token."})
                    websocket_task = asyncio.create_task(connect_and_listen(jwt_token, agent_device_id))

            elif action == "logout":
                gui.send("status_update", {"status": "logged_out", "message": "Logged out."})
            
            elif action == "exit":
                exit_event.set()
                break
        except Exception as e:
            gui.send("error", {"message": f"Invalid command format: {e}"})

    if websocket_task: websocket_task.cancel()
    logging.info("Main loop finished.")

if __name__ == "__main__":
    try: asyncio.run(main_async())
    except KeyboardInterrupt: logging.info("Agent stopped by user.")