import asyncio
import websockets
import json


SERVER_URI = "ws://localhost/ws/connect"

async def connect_to_server():

    print(f"Attempting to connect to {SERVER_URI}...")
    
    async with websockets.connect(SERVER_URI) as websocket:
        print("Successfully connected to the server!")

        print("Waiting for a welcome message from the server...")
        welcome_message_str = await websocket.recv()
        
        welcome_message = json.loads(welcome_message_str)
        
        print(f"<-- Received welcome message: {welcome_message}")
        client_id = welcome_message.get("clientID")
        if client_id:
            print(f"   Our Client ID is: {client_id}")
        
        print("Task complete. Closing connection.")


if __name__ == "__main__":
    try:
        asyncio.run(connect_to_server())
    except KeyboardInterrupt:
        print("\nAgent stopped by user.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")