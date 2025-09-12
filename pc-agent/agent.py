import asyncio
import websockets
import json
import io
import contextlib
import requests
import logging
import sys
import threading

import native_core
from config import IDENTITY_SERVICE_URL, WEBSOCKET_URL

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s', stream=sys.stderr)

def send_event(event_type, data):
    message = json.dumps({"type": event_type, "data": data})
    print(message, flush=True)
    logging.info(f"--> Sent event to GUI: {message}")

def get_jwt_token(username, password) -> str | None:
    login_url = f"{IDENTITY_SERVICE_URL}/api/auth/login"
    logging.info(f"Attempting to log in as '{username}'")
    try:
        response = requests.post(login_url, json={"username": username, "password": password}, timeout=5)
        
        if response.status_code == 200:
            token = response.text
            logging.info("Successfully logged in.")
            return token
        else:
            error_msg = f"Login failed. Status: {response.status_code}, Body: {response.text}"
            logging.error(error_msg)
            send_event("login_failed", {"error": error_msg})
            return None
    except requests.exceptions.RequestException as e:
        error_msg = f"Error connecting to identity service: {e}"
        logging.error(error_msg)
        send_event("login_failed", {"error": error_msg})
        return None

async def listen_for_code(websocket):
    logging.info("Reply listener has started. Waiting for commands...")
    try:
        async for message_str in websocket:
            logging.info(f"<-- Received reply from server: {message_str}")
            try:
                data = json.loads(message_str)
                send_event("message_from_server", data)

                msg_type = data.get("type")
                if msg_type == "code_package":
                    code_to_execute = data.get("code")
                    if not code_to_execute:
                        continue

                    logging.info(f"   [Action] Intent: '{data.get('intent')}'")
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
                        report = {"type": "execution_result", "status": "error", "output": "Security violation: Command blocked by agent's Gate-2."}
                    
                    logging.info(f"   [Reporting] Sending execution result back to server: {report}")
                    send_event("execution_report", report)
                    await websocket.send(json.dumps(report))
            except json.JSONDecodeError:
                logging.warning(f"Received a message that is not valid JSON: {message_str}")
            except Exception as e:
                logging.error(f"An unexpected error occurred in listener: {e}", exc_info=True)
    finally:
        send_event("status_update", {"status": "disconnected", "message": "Lost connection to server."})

async def connect_and_listen(jwt_token: str, device_id: str):
    uri = f"{WEBSOCKET_URL}?clientType=agent&deviceId={device_id}"
    headers = {"Authorization": f"Bearer {jwt_token}"}
    reconnect_delay = 2 

    while True:
        try:
            logging.info(f"Attempting to connect to {uri}")
            send_event("status_update", {"status": "connecting", "message": "Sunucuya bağlanılıyor..."})
            
            async with websockets.connect(uri, extra_headers=headers) as websocket:
                send_event("status_update", {"status": "connected", "message": "Sunucuya başarıyla bağlanıldı."})
                reconnect_delay = 2
                
                await listen_for_code(websocket)

        except (websockets.exceptions.ConnectionClosedError, websockets.exceptions.ConnectionClosedOK, ConnectionRefusedError) as e:
            logging.warning(f"WebSocket connection closed: {e}. Reconnecting in {reconnect_delay}s...")
            send_event("status_update", {"status": "reconnecting", "message": f"Bağlantı koptu. {reconnect_delay} saniye içinde yeniden denenecek..."})
        
        except Exception as e:
            logging.error(f"An unexpected WebSocket error occurred: {e}. Reconnecting in {reconnect_delay}s...")
            send_event("status_update", {"status": "reconnecting", "message": f"Bir hata oluştu. {reconnect_delay} saniye içinde yeniden denenecek..."})

        await asyncio.sleep(reconnect_delay)
        reconnect_delay = min(reconnect_delay * 2, 60)

async def main_async():
    agent_device_id = None
    try:
        pass
    except Exception as e:
        send_event("error", {"message": f"Could not load device ID: {e}"})
        return
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

    send_event("status_update", {"status": "ready", "message": "Ajan komut bekliyor."})

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
                jwt_token = get_jwt_token(username, password)
                if jwt_token:
                    agent_device_id = data.get("deviceId")
                    send_event("login_success", {"message": "Giriş başarılı."})
                    websocket_task = asyncio.create_task(connect_and_listen(jwt_token, agent_device_id))

            elif action == "auto_login_with_token":
                jwt_token = data.get("token")
                if jwt_token:
                    agent_device_id = data.get("deviceId")
                    send_event("login_success", {"message": "Token ile otomatik giriş."})
                    websocket_task = asyncio.create_task(connect_and_listen(jwt_token, agent_device_id))

            elif action == "logout":
                send_event("status_update", {"status": "logged_out", "message": "Çıkış yapıldı."})
            
            elif action == "exit":
                exit_event.set()
                break

        except (json.JSONDecodeError, KeyError) as e:
            send_event("error", {"message": f"Geçersiz komut formatı: {e}"})
        except asyncio.CancelledError:
            break

    if websocket_task:
        websocket_task.cancel()
    logging.info("Main loop finished.")

if __name__ == "__main__":
    try:
        asyncio.run(main_async())
    except KeyboardInterrupt:
        logging.info("Agent stopped by user.")