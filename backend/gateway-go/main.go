package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	pb "llm-remote-assistant/gateway/protos"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}
var clients = make(map[string]*websocket.Conn)
var clientsMutex = sync.Mutex{}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	log.Println("-> [Gateway] New connection attempt received...")

	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		log.Println("!!! [Auth] Connection rejected: Missing Authorization header.")
		http.Error(w, "Unauthorized: Missing Authorization header", http.StatusUnauthorized)
		return
	}

	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		log.Println("!!! [Auth] Connection rejected: Malformed Authorization header. Must be 'Bearer <token>'.")
		http.Error(w, "Unauthorized: Malformed Authorization header", http.StatusUnauthorized)
		return
	}

	tokenString := parts[1]
	if tokenString == "" {
		log.Println("!!! [Auth] Connection rejected: Token is empty.")
		http.Error(w, "Unauthorized: Token is empty", http.StatusUnauthorized)
		return
	}

	log.Printf("-> [Auth] Token received. Proceeding to upgrade connection. (Verification in next step)")

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
		var incomingMessage map[string]interface{}
		if err := json.Unmarshal(p, &incomingMessage); err == nil {
			if msgType, ok := incomingMessage["type"].(string); ok && msgType == "execution_result" {
				log.Printf("<- [Gateway] Received Execution Result from %s: %s", clientID, string(p))
				continue
			}
		}

		log.Printf("-> [Gateway] Received command from %s, forwarding to Python...", clientID)
		go forwardMessageToPython(clientID, p)
	}
}

func forwardMessageToPython(clientID string, message []byte) {
	addr := "orchestrator-py:50051"

	conn, err := grpc.NewClient(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Printf("!!! [gRPC Client] Did not connect to orchestrator: %v", err)
		return
	}
	defer conn.Close()

	c := pb.NewOrchestratorServiceClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*15)
	defer cancel()

	r, err := c.ProcessCommand(ctx, &pb.ProcessRequest{
		ClientId:    clientID,
		MessageJson: string(message),
	})
	if err != nil {
		log.Printf("!!! [gRPC Client] Could not process command for client %s: %v", clientID, err)
		return
	}

	log.Printf("[gRPC Client] Received gRPC response from orchestrator for client %s", clientID)

	clientsMutex.Lock()
	defer clientsMutex.Unlock()

	if clientConn, found := clients[clientID]; found {
		err := clientConn.WriteMessage(websocket.TextMessage, []byte(r.GetMessage()))
		if err != nil {
			log.Printf("!!! [Gateway] Error sending gRPC response via WebSocket to client %s: %v", clientID, err)
		} else {
			log.Printf("--> [Gateway] Successfully sent generated code to client %s", clientID)
		}
	} else {
		log.Printf("!!! [Gateway] Client %s disconnected before gRPC response could be sent.", clientID)
	}
}

func main() {
	publicMux := http.NewServeMux()
	publicMux.HandleFunc("/ws/connect", handleConnections)

	log.Println("Public server starting on 0.0.0.0:8080")
	if err := http.ListenAndServe("0.0.0.0:8080", publicMux); err != nil {
		log.Fatalf("Failed to start public server: %v", err)
	}
}
