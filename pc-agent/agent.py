import asyncio
import websockets
import json


SERVER_URI = "ws://localhost/ws/connect"

async def send_commands(websocket):

    print("Command sender has started.")
    
    test_prompt = "create a text file on the desktop named 'hello.txt' and write 'Hello from the agent!' inside it"
    
    while True:
        try:
            command_message = {
                "type": "command",
                "prompt": test_prompt
            }
            message_str = json.dumps(command_message)
            
            await websocket.send(message_str)
            print(f"--> Sent command to server: {test_prompt}")
            
            await asyncio.sleep(15)
        except websockets.exceptions.ConnectionClosed:
            print("Connection closed. Stopping command sender.")
            break

async def listen_for_replies(websocket):
    print("Reply listener has started.")
    while True:
        try:
            message_str = await websocket.recv()

            print(f"<-- Received reply from server: {message_str}")
        
        except websockets.exceptions.ConnectionClosed:
            print("Connection closed. Stopping reply listener.")
            break

async def connect_to_server():

    print(f"Attempting to connect to {SERVER_URI}...")
    
    async with websockets.connect(SERVER_URI) as websocket:
        print("Successfully connected to the server!")

        welcome_message_str = await websocket.recv()
        
        listen_task = asyncio.create_task(listen_for_replies(websocket))
        send_task = asyncio.create_task(send_commands(websocket)) 

        done, pending = await asyncio.wait(
            [listen_task, send_task],
            return_when=asyncio.FIRST_COMPLETED,
        )

        for task in pending:
            task.cancel()
        
        print("One of the main tasks completed. Closing connection.")
        

if __name__ == "__main__":
    try:
        asyncio.run(connect_to_server())
    except KeyboardInterrupt:
        print("\nAgent stopped by user.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")