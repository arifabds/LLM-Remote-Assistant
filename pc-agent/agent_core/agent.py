import asyncio
import json
import io
import contextlib
import logging
import sys
import threading

from .gui_communicator import GuiCommunicator
from .api_client import ApiClient
from .websocket_client import WebSocketClient
import native_core

class AgentCore:
    def __init__(self):
        self.gui = GuiCommunicator()
        self.api = ApiClient()
        self.websocket_client: WebSocketClient | None = None
        self.websocket_task: asyncio.Task | None = None
        self.command_queue = asyncio.Queue()
        self.exit_event = asyncio.Event()

    async def _handle_server_message(self, message_str: str):
        logging.info(f"<-- Received reply from server: {message_str}")
        try:
            data = json.loads(message_str)
            self.gui.send("message_from_server", data)
            msg_type = data.get("type")
            if msg_type == "code_package":
                code_to_execute = data.get("code")
                command_id = data.get("commandId", "unknown-id")
                if not code_to_execute: return
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
                    report = {"type": "execution_result", "status": "success" if execution_successful else "error", "output": output.strip(), "commandId": command_id}
                else:
                    report = {"type": "execution_result", "status": "error", "output": "Security violation: Command blocked by agent's Gate-2.", "commandId": command_id}
                self.gui.send("execution_report", report)
                if self.websocket_client:
                    await self.websocket_client.send(json.dumps(report))
            elif msg_type == "pairing_complete":
                logging.info(f"   [Action] Pairing complete notification received. Notifying GUI.")
                self.gui.send("event_pairing_complete", {})
        except Exception as e:
            logging.error(f"An unexpected error occurred in message handler: {e}", exc_info=True)

    def _start_stdin_reader(self, loop):
        def stdin_reader():
            for line in sys.stdin:
                if not self.exit_event.is_set():
                    loop.call_soon_threadsafe(self.command_queue.put_nowait, line)
        reader_thread = threading.Thread(target=stdin_reader, daemon=True)
        reader_thread.start()

    async def run(self):
        loop = asyncio.get_running_loop()
        self._start_stdin_reader(loop)
        self.gui.send("status_update", {"status": "waiting_for_login", "message": "Waiting for login..."})

        while not self.exit_event.is_set():
            try:
                command_str = await self.command_queue.get()
                command = json.loads(command_str.strip())
                action = command.get("action")
                data = command.get("data", {})

                if self.websocket_task and not self.websocket_task.done():
                    if self.websocket_client: self.websocket_client.disconnect()
                    self.websocket_task.cancel()
                    await asyncio.sleep(0.1)

                if action == "login" or action == "auto_login_with_token":
                    jwt_token = None
                    if action == "login":
                        username = data.get("username")
                        password = data.get("password")
                        jwt_token = self.api.login(username, password)
                    else:
                        jwt_token = data.get("token")
                    
                    if jwt_token:
                        agent_device_id = data.get("deviceId")
                        self.gui.send("login_success", {"message": "Login successful." if action == "login" else "Auto-login with token."})
                        self.websocket_client = WebSocketClient(
                            jwt_token=jwt_token, 
                            device_id=agent_device_id,
                            on_message_callback=self._handle_server_message,
                            gui=self.gui
                        )
                        self.websocket_task = asyncio.create_task(self.websocket_client.connect())
                    elif action == "login":
                        self.gui.send("login_failed", {"error": "Invalid username or password from API."})

            except Exception as e:
                self.gui.send("error", {"message": f"Invalid command format: {e}"})

        if self.websocket_client: self.websocket_client.disconnect()
        if self.websocket_task: self.websocket_task.cancel()
        logging.info("Main loop finished.")