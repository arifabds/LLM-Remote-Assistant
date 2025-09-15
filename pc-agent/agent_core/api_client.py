import logging
import requests
from config import IDENTITY_SERVICE_URL

class ApiClient:
    def __init__(self):
        self.base_url = IDENTITY_SERVICE_URL

    def login(self, username, password) -> str | None:
        login_url = f"{self.base_url}/api/auth/login"
        logging.info(f"Attempting to log in as '{username}' at {login_url}")
        try:
            response = requests.post(login_url, json={"username": username, "password": password}, timeout=10)
            
            if response.status_code == 200:
                token = response.text
                logging.info("Successfully logged in and received token.")
                return token
            else:
                logging.error(f"Login failed. Status: {response.status_code}, Body: {response.text}")
                return None
        except requests.exceptions.RequestException as e:
            logging.error(f"Error connecting to identity service: {e}")
            return None