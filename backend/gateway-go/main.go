package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
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
		_, p, err := ws.ReadMessage()
		if err != nil {
			break
		}
		log.Printf("Received message from %s, forwarding to Python...", clientID)
		go forwardMessageToPython(clientID, p)
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

func forwardMessageToPython(clientID string, message []byte) {
	requestBody, err := json.Marshal(map[string]interface{}{
		"clientId": clientID,
		"message":  json.RawMessage(message),
	})
	if err != nil {
		log.Printf("Error marshalling request for Python: %v", err)
		return
	}

	resp, err := http.Post("http://orchestrator-py:8000/api/v1/process", "application/json", bytes.NewBuffer(requestBody))
	if err != nil {
		log.Printf("Error forwarding message to Python: %v", err)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	log.Printf("Received response from Python for client %s: Status: %s, Body: %s", clientID, resp.Status, string(body))
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
