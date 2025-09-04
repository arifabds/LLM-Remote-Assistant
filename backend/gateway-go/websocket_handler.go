package main

import (
	"context"
	"crypto/rsa"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	pb "llm-remote-assistant/gateway/protos"

	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

var (
	verifyKey *rsa.PublicKey
	upgrader  = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}
)

func init() {
	keyData, err := os.ReadFile("keys/publicKey.pem")
	if err != nil {
		log.Fatalf("!!! [JWT Init] Error reading public key: %v", err)
	}
	verifyKey, err = jwt.ParseRSAPublicKeyFromPEM(keyData)
	if err != nil {
		log.Fatalf("!!! [JWT Init] Error parsing public key: %v", err)
	}
	log.Println("-> [JWT Init] Public key loaded and parsed successfully.")
}

func handleConnections(cm *ConnectionManager, w http.ResponseWriter, r *http.Request) {
	authHeader := r.Header.Get("Authorization")
	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		http.Error(w, "Unauthorized: Malformed Authorization header", http.StatusUnauthorized)
		return
	}

	userId, err := parseAndValidateToken(parts[1])
	if err != nil {
		log.Printf("!!! [Auth] Invalid Token: %v", err)
		http.Error(w, "Unauthorized: Invalid Token", http.StatusUnauthorized)
		return
	}
	log.Printf("-> [Auth] Token validated for userId: %s. Upgrading connection...", userId)

	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("!!! [Handler] WebSocket upgrade error: %v", err)
		return
	}
	defer ws.Close()

	connectionId := cm.RegisterConnection(userId, ws)
	defer cm.UnregisterConnection(userId, ws)

	welcomeMessage := fmt.Sprintf(`{"type":"welcome", "connectionId":"%s", "userId":"%s"}`, connectionId, userId)
	ws.WriteMessage(websocket.TextMessage, []byte(welcomeMessage))

	for {
		_, p, err := ws.ReadMessage()
		if err != nil {
			break
		}

		var incomingMessage map[string]interface{}
		if err := json.Unmarshal(p, &incomingMessage); err == nil {
			if msgType, ok := incomingMessage["type"].(string); ok && msgType == "execution_result" {
				log.Printf("<- [Handler] Received Execution Result from userId %s", userId)
				continue
			}
		}

		log.Printf("-> [Handler] Received command from userId %s, forwarding to gRPC...", userId)
		go forwardMessageToPython(cm, userId, p)
	}
}

func forwardMessageToPython(cm *ConnectionManager, userId string, message []byte) {
	addr := "orchestrator-py:50051"
	conn, err := grpc.NewClient(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Printf("!!! [gRPC] Did not connect: %v", err)
		return
	}
	defer conn.Close()

	c := pb.NewOrchestratorServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	r, err := c.ProcessCommand(ctx, &pb.ProcessRequest{ClientId: userId, MessageJson: string(message)})
	if err != nil {
		log.Printf("!!! [gRPC] Could not process command for user %s: %v", userId, err)
		return
	}

	log.Printf("[gRPC] Received response for user %s. Broadcasting...", userId)
	cm.BroadcastToUser(userId, []byte(r.GetMessage()))
}

func parseAndValidateToken(tokenString string) (string, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return verifyKey, nil
	})

	if err != nil {
		return "", err
	}
	if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
		if sub, ok := claims["sub"].(string); ok {
			return sub, nil
		}
		return "", errors.New("sub claim (userId) not found in token")
	}
	return "", errors.New("invalid token")
}
