import asyncio
import websockets
import logging
from config import WEBSOCKET_URL
from .gui_communicator import GuiCommunicator

class WebSocketClient:
    def __init__(self, jwt_token: str, device_id: str, on_message_callback, gui: GuiCommunicator):
        self._jwt_token = jwt_token
        self._device_id = device_id
        self._on_message_callback = on_message_callback
        self._gui = gui
        self._uri = f"{WEBSOCKET_URL}?clientType=agent&deviceId={self._device_id}"
        self._headers = {"Authorization": f"Bearer {self._jwt_token}"}
        self._connection = None
        self._is_running = False
        self._reconnect_delay = 2

    async def connect(self):
        self._is_running = True
        while self._is_running:
            try:
                self._gui.send("status_update", {"status": "connecting", "message": "Connecting to server..."})
                async with websockets.connect(self._uri, extra_headers=self._headers) as websocket:
                    self._connection = websocket
                    self._gui.send("status_update", {"status": "connected", "message": "Successfully connected to server."})
                    self._gui.send("status_update", {"status": "ready", "message": "Agent is ready for commands."})
                    self._reconnect_delay = 2
                    await self._listen_for_code()
            except (websockets.exceptions.ConnectionClosedError, websockets.exceptions.ConnectionClosedOK, ConnectionRefusedError, OSError) as e:
                logging.warning(f"WebSocket connection lost: {e}. Reconnecting in {self._reconnect_delay}s...")
                self._gui.send("status_update", {"status": "reconnecting", "message": f"Connection lost. Reconnecting in {self._reconnect_delay}s..."})
            except Exception as e:
                logging.error(f"An unexpected WebSocket error occurred: {e}. Reconnecting in {self._reconnect_delay}s...")
                self._gui.send("status_update", {"status": "reconnecting", "message": f"An error occurred. Reconnecting in {self._reconnect_delay}s..."})
            
            if self._is_running:
                await asyncio.sleep(self._reconnect_delay)
                self._reconnect_delay = min(self._reconnect_delay * 2, 60)

    async def _listen_for_code(self):
        logging.info("Reply listener has started. Waiting for commands...")
        try:
            async for message in self._connection:
                await self._on_message_callback(message)
        finally:
            self._connection = None

    async def send(self, message: str):
        if self._connection and self._connection.open:
            await self._connection.send(message)
        else:
            logging.warning("Cannot send message, WebSocket is not connected.")

    def disconnect(self):
        self._is_running = False
        logging.info("WebSocket client disconnect requested.")