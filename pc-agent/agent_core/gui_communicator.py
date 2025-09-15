import json
import logging
import sys

class GuiCommunicator:
    def __init__(self):
        logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s', stream=sys.stderr)

    def send(self, event_type: str, data: dict):
        message = json.dumps({"type": event_type, "data": data})
        print(message, flush=True)
        logging.info(f"--> [GUI] Sent event: {message}")