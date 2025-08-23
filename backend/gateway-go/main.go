package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

var clients = make(map[string]*websocket.Conn)
var clientsMutex = sync.Mutex{}

type SendMessageRequest struct {
	ClientID string         `json:"clientId"`
	Payload  map[string]any `json:"payload"`
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Error upgrading to websocket: %v\n", err)
		return
	}
	defer ws.Close()

	clientID := uuid.New().String()

	clientsMutex.Lock()
	clients[clientID] = ws
	clientsMutex.Unlock()
	log.Printf("Client connected: %s", clientID)

	defer func() {
		clientsMutex.Lock()
		delete(clients, clientID)
		clientsMutex.Unlock()
		log.Printf("Client disconnected: %s", clientID)
	}()

	welcomeMessage := fmt.Sprintf("{\"type\":\"welcome\", \"clientID\":\"%s\"}", clientID)
	if err := ws.WriteMessage(websocket.TextMessage, []byte(welcomeMessage)); err != nil {
		log.Printf("Error sending welcome message to %s: %v\n", clientID, err)
		return
	}

	for {
		messageType, p, err := ws.ReadMessage()
		if err != nil {
			break
		}
		log.Printf("Received message from %s: Type: %d, Message: %s\n", clientID, messageType, string(p))
	}
}

func handleSendMessage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req SendMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Bad request: Invalid JSON", http.StatusBadRequest)
		return
	}

	if req.ClientID == "" || req.Payload == nil {
		http.Error(w, "Bad request: clientId and payload are required", http.StatusBadRequest)
		return
	}

	clientsMutex.Lock()
	defer clientsMutex.Unlock()

	clientConn, found := clients[req.ClientID]
	if !found {
		http.Error(w, "Client not found", http.StatusNotFound)
		return
	}

	messageBytes, err := json.Marshal(req.Payload)
	if err != nil {
		http.Error(w, "Internal server error: Could not marshal payload", http.StatusInternalServerError)
		return
	}

	if err := clientConn.WriteMessage(websocket.TextMessage, messageBytes); err != nil {
		log.Printf("Error writing message to client %s: %v", req.ClientID, err)
		http.Error(w, "Internal server error: Failed to write message", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Message sent successfully"))
}

func main() {
	publicMux := http.NewServeMux()
	publicMux.HandleFunc("/ws/connect", handleConnections)

	internalMux := http.NewServeMux()
	internalMux.HandleFunc("/internal/send-message", handleSendMessage)

	go func() {
		log.Println("Public server starting on 0.0.0.0:8080")
		if err := http.ListenAndServe("0.0.0.0:8080", publicMux); err != nil {
			log.Fatalf("Failed to start public server: %v", err)
		}
	}()

	go func() {
		log.Println("Internal server starting on 0.0.0.0:8081")
		if err := http.ListenAndServe("0.0.0.0:8081", internalMux); err != nil {
			log.Fatalf("Failed to start internal server: %v", err)
		}
	}()

	log.Println("Servers are running. Press CTRL+C to exit.")
	select {}
}
