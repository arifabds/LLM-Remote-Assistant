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
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

const (
	pingPeriod = (pongWait * 9) / 10

	pongWait = 45 * time.Second

	writeWait = 10 * time.Second
)

var (
	verifyKey *rsa.PublicKey
	upgrader  = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}
)

type Connection struct {
	Conn       *websocket.Conn
	ConnId     string
	UserId     string
	ClientType string
}

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

	clientType := r.URL.Query().Get("clientType")
	if clientType != "mobile" && clientType != "agent" {
		log.Printf("!!! [Handler] Connection rejected for userId %s: Invalid or missing clientType query parameter.", userId)
		http.Error(w, "Bad Request: clientType query parameter must be 'mobile' or 'agent'", http.StatusBadRequest)
		return
	}
	log.Printf("-> [Auth] Token validated for userId: %s, clientType: %s. Upgrading connection...", userId, clientType)

	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("!!! [Handler] WebSocket upgrade error: %v", err)
		return
	}

	connWrapper := &Connection{
		Conn:       ws,
		ConnId:     uuid.New().String(),
		UserId:     userId,
		ClientType: clientType,
	}
	cm.RegisterConnection(connWrapper)

	go readPump(cm, connWrapper)

	go writePump(connWrapper)
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
		// TODO mobile client feedback
		return
	}

	responseMessage := []byte(r.GetMessage())

	var payload map[string]interface{}
	if err := json.Unmarshal(responseMessage, &payload); err != nil {
		log.Printf("... [gRPC] Could not unmarshal gRPC response, assuming it's for agent: %v", err)
		cm.SendToAgentsOfUser(userId, responseMessage)
		return
	}

	if msgType, ok := payload["type"].(string); ok && msgType == "confirmation_required" {
		log.Printf("--> [gRPC] Received confirmation request for user %s. Forwarding to mobiles...", userId)
		cm.SendToMobilesOfUser(userId, responseMessage)
	} else {
		log.Printf("--> [gRPC] Received code payload for user %s. Forwarding to agents...", userId)
		cm.SendToAgentsOfUser(userId, responseMessage)
	}
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

func readPump(cm *ConnectionManager, conn *Connection) {
	defer func() {
		cm.UnregisterConnection(conn)
		conn.Conn.Close()
	}()

	conn.Conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.Conn.SetPongHandler(func(string) error {
		conn.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, p, err := conn.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("!!! [ReadPump] Unexpected close error for %s: %v", conn.ConnId, err)
			}
			break
		}

		var incomingMessage map[string]interface{}
		if err := json.Unmarshal(p, &incomingMessage); err == nil {
			msgType, _ := incomingMessage["type"].(string)
			if conn.ClientType == "mobile" && msgType == "command" {
				log.Printf("-> [ReadPump] Received command from mobile (userId %s)", conn.UserId)
				go forwardMessageToPython(cm, conn.UserId, p)
			} else if conn.ClientType == "agent" && msgType == "execution_result" {
				log.Printf("<- [ReadPump] Received result from agent (userId %s)", conn.UserId)
				go cm.SendToMobilesOfUser(conn.UserId, p)
			}
		}
	}
}

func writePump(conn *Connection) {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		conn.Conn.Close()
	}()

	welcomeMessage := fmt.Sprintf(`{"type":"welcome", "connectionId":"%s", "userId":"%s"}`, conn.ConnId, conn.UserId)
	conn.Conn.SetWriteDeadline(time.Now().Add(writeWait))
	if err := conn.Conn.WriteMessage(websocket.TextMessage, []byte(welcomeMessage)); err != nil {
		log.Printf("!!! [WritePump] Error sending welcome to %s: %v", conn.ConnId, err)
		return
	}

	for range ticker.C {
		conn.Conn.SetWriteDeadline(time.Now().Add(writeWait))
		if err := conn.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
			log.Printf("!!! [WritePump] Error sending ping to %s: %v", conn.ConnId, err)
			return
		}
	}
}
