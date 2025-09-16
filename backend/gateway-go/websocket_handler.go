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
	log.Printf("[%dms] [LOG-GO-HANDLER-START] handleConnections triggered for remote address: %s", time.Since(startTime).Milliseconds(), r.RemoteAddr)
	authHeader := r.Header.Get("Authorization")
	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		log.Printf("[%dms] [LOG-GO-HANDLER-FAIL] Malformed Authorization header. Rejecting with 401.", time.Since(startTime).Milliseconds())
		http.Error(w, "Unauthorized: Malformed Authorization header", http.StatusUnauthorized)
		return
	}

	userId, err := parseAndValidateToken(parts[1])
	if err != nil {
		log.Printf("[%dms] [LOG-GO-HANDLER-FAIL] Invalid Token: %v. Rejecting with 401.", time.Since(startTime).Milliseconds(), err)
		http.Error(w, "Unauthorized: Invalid Token", http.StatusUnauthorized)
		return
	}
	log.Printf("[%dms] [LOG-GO-HANDLER-AUTH-SUCCESS] Token validated for userId: %s.", time.Since(startTime).Milliseconds(), userId)

	clientType := r.URL.Query().Get("clientType")
	if clientType != "mobile" && clientType != "agent" {
		log.Printf("[%dms] [LOG-GO-HANDLER-FAIL] Invalid clientType '%s' for userId %s. Rejecting with 400.", time.Since(startTime).Milliseconds(), clientType, userId)
		http.Error(w, "Bad Request: clientType query parameter must be 'mobile' or 'agent'", http.StatusBadRequest)
		return
	}

	deviceId := r.URL.Query().Get("deviceId")
	if deviceId == "" {
		log.Printf("[%dms] [LOG-GO-HANDLER-FAIL] Missing deviceId for userId %s. Rejecting with 400.", time.Since(startTime).Milliseconds(), userId)
		http.Error(w, "Bad Request: deviceId query parameter is required", http.StatusBadRequest)
		return
	}
	log.Printf("[%dms] [LOG-GO-HANDLER-PARAMS-VALID] All params valid for userId: %s, clientType: %s, deviceId: %s. Upgrading connection...", time.Since(startTime).Milliseconds(), userId, clientType, deviceId)

	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[%dms] [LOG-GO-HANDLER-FAIL] WebSocket upgrade error: %v", time.Since(startTime).Milliseconds(), err)
		return
	}
	log.Printf("[%dms] [LOG-GO-HANDLER-UPGRADE-SUCCESS] Connection upgraded to WebSocket.", time.Since(startTime).Milliseconds())

	connWrapper := &Connection{
		Conn:       ws,
		ConnId:     uuid.New().String(),
		DeviceId:   deviceId,
		UserId:     userId,
		ClientType: clientType,
	}
	cm.RegisterConnection(connWrapper)

	log.Printf("[%dms] [LOG-GO-HANDLER-PUMPS-START] Starting readPump and writePump for connId: %s.", time.Since(startTime).Milliseconds(), connWrapper.ConnId)
	go readPump(cm, connWrapper)
	go writePump(connWrapper)
}

func readPump(cm *ConnectionManager, conn *Connection) {
	log.Printf("[%dms] [LOG-GO-READPUMP-START] readPump started for connId: %s.", time.Since(startTime).Milliseconds(), conn.ConnId)
	defer func() {
		log.Printf("[%dms] [LOG-GO-READPUMP-DEFER] defer function in readPump triggered for connId: %s. Unregistering and closing.", time.Since(startTime).Milliseconds(), conn.ConnId)
		cm.UnregisterConnection(conn)
		conn.Conn.Close()
	}()
	conn.Conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.Conn.SetPongHandler(func(string) error {
		log.Printf("[%dms] [LOG-GO-READPUMP-PONG] Pong received for connId: %s. Resetting read deadline.", time.Since(startTime).Milliseconds(), conn.ConnId)
		conn.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	for {
		msgType, p, err := conn.Conn.ReadMessage()
		if err != nil {
			log.Printf("[%dms] [LOG-GO-READPUMP-FAIL] readPump for connId %s exiting due to error: %v.", time.Since(startTime).Milliseconds(), conn.ConnId, err)
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("--> [DEBUG-GO] The error for connId %s was an unexpected close error.", conn.ConnId)
			}
			break
		}
		log.Printf("[%dms] [LOG-GO-READPUMP-MSG-RECV] Message of type %d received for connId %s.", time.Since(startTime).Milliseconds(), msgType, conn.ConnId)
		var incomingMessage map[string]interface{}
		if err := json.Unmarshal(p, &incomingMessage); err == nil {
			msgTypeStr, _ := incomingMessage["type"].(string)
			if conn.ClientType == "mobile" && msgTypeStr == "command" {
				log.Printf("[%dms] [LOG-GO-READPUMP-ACTION] Forwarding command from mobile (userId %s) to gRPC stream.", time.Since(startTime).Milliseconds(), conn.UserId)
				go orchestratorClient.ForwardCommandStream(cm, conn.UserId, p)
			} else if conn.ClientType == "agent" && msgTypeStr == "execution_result" {
				log.Printf("[%dms] [LOG-GO-READPUMP-ACTION] Forwarding agent result (userId %s) to mobiles.", time.Since(startTime).Milliseconds(), conn.UserId)
				go cm.SendToMobilesOfUser(conn.UserId, p)
			} else if conn.ClientType == "mobile" && msgTypeStr == "confirmation_response" {
				log.Printf("[%dms] [LOG-GO-READPUMP-ACTION] Forwarding mobile confirmation (userId %s) to gRPC.", time.Since(startTime).Milliseconds(), conn.UserId)
				go orchestratorClient.HandleConfirmation(conn.UserId, p)
			}
		}
	}
}

func writePump(conn *Connection) {
	log.Printf("[%dms] [LOG-GO-WRITEPUMP-START] writePump started for connId: %s.", time.Since(startTime).Milliseconds(), conn.ConnId)
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		log.Printf("[%dms] [LOG-GO-WRITEPUMP-DEFER] defer function in writePump triggered for connId: %s. Stopping ticker and closing connection.", time.Since(startTime).Milliseconds(), conn.ConnId)
		ticker.Stop()
		conn.Conn.Close()
	}()
	welcomeMessage := fmt.Sprintf(`{"type":"welcome", "connectionId":"%s", "userId":"%s"}`, conn.ConnId, conn.UserId)
	conn.Conn.SetWriteDeadline(time.Now().Add(writeWait))
	if err := conn.Conn.WriteMessage(websocket.TextMessage, []byte(welcomeMessage)); err != nil {
		log.Printf("[%dms] [LOG-GO-WRITEPUMP-FAIL] Error sending welcome to %s: %v. Exiting pump.", time.Since(startTime).Milliseconds(), conn.ConnId, err)
		return
	}
	log.Printf("[%dms] [LOG-GO-WRITEPUMP-WELCOME-SENT] Welcome message sent to %s.", time.Since(startTime).Milliseconds(), conn.ConnId)
	for range ticker.C {
		conn.Conn.SetWriteDeadline(time.Now().Add(writeWait))
		if err := conn.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
			log.Printf("[%dms] [LOG-GO-WRITEPUMP-FAIL] Error sending ping to %s: %v. Exiting pump.", time.Since(startTime).Milliseconds(), conn.ConnId, err)
			return
		}
		// log.Printf("[%dms] [LOG-GO-WRITEPUMP-PING] Ping sent to %s.", time.Since(startTime).Milliseconds(), conn.ConnId)
	}
}
