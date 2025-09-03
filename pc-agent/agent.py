import asyncio
import websockets
import json
import io           
import contextlib
import native_core 

SERVER_URI = "ws://localhost/ws/connect"

async def send_commands(websocket):

    print("Command sender has started.")
    
    test_prompt = "create a text file on the desktop named 'safe_test.txt' and write 'This is safe' inside it"
    
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

            try:
                data = json.loads(message_str)
            except json.JSONDecodeError:
                print("   [Warning] Received a message that is not valid JSON.")
                continue

            if data.get("type") == "welcome":
                client_id = data.get("clientID")
                if client_id:
                    print(f"   Successfully registered with Client ID: {client_id}")
                continue 

            intent = data.get("intent")
            code_to_execute = data.get("code")

            if intent and code_to_execute:
                print(f"   [Action] Intent received: '{intent}'")
                
                print("   [Security] Analyzing code with native security engine...")
                is_safe = native_core.analyze_code(code_to_execute)
                
                report = {}
                
                if is_safe:
                    print("   [Security] ✅ Code is safe. Proceeding with execution.")
                    print(f"   [Action] Code to execute: \n--- START CODE ---\n{code_to_execute}\n--- END CODE ---")
                    
                    execution_successful = True
                    execution_output = ""
                    try:
                        print("   [Execution] Running the received code and capturing output...")
                        output_stream = io.StringIO()
                        
                        with contextlib.redirect_stdout(output_stream):
                            exec(code_to_execute)
                        
                        execution_output = output_stream.getvalue()
                        
                        print("   [Execution] Code executed successfully.")
                        if execution_output:
                            print(f"   [Execution] Captured output:\n--- START OUTPUT ---\n{execution_output.strip()}\n--- END OUTPUT ---")
                        else:
                            print("   [Execution] Code produced no output.")
                    
                    except Exception as e:
                        print(f"   [Execution] ❌ An error occurred while executing the code: {e}")
                        execution_output = f"Error: {e}"
                        execution_successful = False
                    
                    report = {
                        "type": "execution_result",
                        "status": "success" if execution_successful else "error",
                        "output": execution_output.strip()
                    }
                
                else:
                    print("   [Security] ❌ DANGEROUS CODE DETECTED! Execution aborted.")
                    execution_output = "Security violation: Malicious code detected. Execution was blocked by the agent."
                    
                    report = {
                        "type": "execution_result",
                        "status": "error",
                        "output": execution_output
                    }

                print("   [Reporting] Sending execution result back to the server...")
                await websocket.send(json.dumps(report))
                print("   [Reporting] Result sent successfully.")
                
            else:
                print(f"   [Info] Received a non-actionable message: {data}")
        
        except websockets.exceptions.ConnectionClosed:
            print("Connection closed. Stopping reply listener.")
            break


async def connect_to_server():

    print(f"Attempting to connect to {SERVER_URI}...")
    
    async with websockets.connect(SERVER_URI) as websocket:
        print("Successfully connected to the server!")
        
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