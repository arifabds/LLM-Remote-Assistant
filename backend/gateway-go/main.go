package main

import (
	"fmt"
	"net/http"

	"sync"

	"github.com/gorilla/websocket"

	"github.com/google/uuid"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// Clients map
var clients = make(map[string]*websocket.Conn)

// Clients map mutex
var clientsMutex = sync.Mutex{}

// JSON request structure
type SendMessageRequest struct {
	ClientID string `json:"clientId"`

	Payload map[string]any `json:"payload"`
}

func handleConnections(w http.ResponseWriter, r *http.Request) {

	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		fmt.Printf("Error upgrading to websocket: %s\n", err)
		return
	}

	defer ws.Close()

	//Unique client ID
	clientID := uuid.New().String()
	fmt.Printf("Gateway-go: New client connected with ID: %s\n", clientID)

	//Map registration
	clientsMutex.Lock()
	clients[clientID] = ws

	clientsMutex.Unlock()

	//Map deletion when an error occurs
	defer func() {
		clientsMutex.Lock()
		delete(clients, clientID)
		clientsMutex.Unlock()
		fmt.Printf("Gateway-go: Client disconnected with ID: %s\n", clientID)
	}()

	//Welcome message
	welcomeMessage := fmt.Sprintf("{\"type\":\"welcome\", \"clientID\":\"%s\"}", clientID)
	if err := ws.WriteMessage(websocket.TextMessage, []byte(welcomeMessage)); err != nil {
		fmt.Printf("Error sending welcome message to %s: %s\n", clientID, err)
		return
	}

	//Listen client messages
	for {
		messageType, p, err := ws.ReadMessage()
		if err != nil {
			fmt.Printf("Error reading message from %s: %s\n", clientID, err)
			break
		}
		fmt.Printf("Gateway-go: Received message from %s: Type: %d, Message: %s\n", clientID, messageType, string(p))

		// TODO: Forward message to orchestrator-py
	}
}

func main() {
	// /ws paths redirect to handleConnections
	http.HandleFunc("/ws/connect", handleConnections)

	fmt.Println("Gateway-go server starting on port 8080")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		// Error logging
		fmt.Printf("Error starting server: %s\n", err)
	}
}
