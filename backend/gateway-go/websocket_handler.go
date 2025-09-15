package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

const (
	pingPeriod = (pongWait * 9) / 10
	pongWait   = 10 * time.Second
	writeWait  = 10 * time.Second
)

var (
	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}
	orchestratorClient = NewOrchestratorClient("orchestrator-py:50051")
)

type Connection struct {
	Conn       *websocket.Conn
	ConnId     string
	DeviceId   string
	UserId     string
	ClientType string
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

	deviceId := r.URL.Query().Get("deviceId")
	if deviceId == "" {
		log.Printf("!!! [Handler] Connection rejected for userId %s: Missing deviceId query parameter.", userId)
		http.Error(w, "Bad Request: deviceId query parameter is required", http.StatusBadRequest)
		return
	}
	log.Printf("-> [Auth] Token validated for userId: %s, clientType: %s, deviceId: %s. Upgrading connection...", userId, clientType, deviceId)

	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("!!! [Handler] WebSocket upgrade error: %v", err)
		return
	}

	connWrapper := &Connection{
		Conn:       ws,
		ConnId:     uuid.New().String(),
		DeviceId:   deviceId,
		UserId:     userId,
		ClientType: clientType,
	}
	cm.RegisterConnection(connWrapper)

	go readPump(cm, connWrapper)
	go writePump(connWrapper)
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
				go orchestratorClient.ForwardCommandStream(cm, conn.UserId, p)
			} else if conn.ClientType == "agent" && msgType == "execution_result" {
				log.Printf("<- [ReadPump] Received result from agent (userId %s)", conn.UserId)
				go cm.SendToMobilesOfUser(conn.UserId, p)
			} else if conn.ClientType == "mobile" && msgType == "confirmation_response" {
				log.Printf("<- [ReadPump] Received confirmation from mobile (userId %s)", conn.UserId)
				go orchestratorClient.HandleConfirmation(conn.UserId, p)
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
