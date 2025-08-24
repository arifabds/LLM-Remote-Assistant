import asyncio
import websockets
import json


SERVER_URI = "ws://localhost/ws/connect"

async def send_pings(websocket):
    print("Ping sender has started.")
    while True:
        try:
            ping_message = {
                "command": "ping"
            }

            message_str = json.dumps(ping_message)
            
            await websocket.send(message_str)
            print(f"--> Sent ping to server: {message_str}")
            
            await asyncio.sleep(5)
        except websockets.exceptions.ConnectionClosed:
            print("Connection closed. Stopping ping sender.")
            break

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


        ping_task = asyncio.create_task(send_pings(websocket))
        

        print("Agent is running. Sending pings for 12 seconds...")
        await asyncio.sleep(12)

        ping_task.cancel()
        print("Test duration over. Stopping agent.")
        

if __name__ == "__main__":
    try:
        asyncio.run(connect_to_server())
    except KeyboardInterrupt:
        print("\nAgent stopped by user.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")