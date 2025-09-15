package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	pb "llm-remote-assistant/gateway/protos"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
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

func forwardMessageToPython(cm *ConnectionManager, userId string, message []byte) {
	var requestData map[string]interface{}
	if err := json.Unmarshal(message, &requestData); err != nil {
		log.Printf("!!! [gRPC] Could not unmarshal incoming message for user %s: %v", userId, err)
		return
	}
	commandId, _ := requestData["commandId"].(string)
	if commandId == "" {
		log.Printf("!!! [gRPC] Missing commandId in request from user %s. Aborting.", userId)
		return
	}
	addr := "orchestrator-py:50051"
	conn, err := grpc.NewClient(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Printf("!!! [gRPC] Did not connect: %v", err)
		return
	}
	defer conn.Close()
	c := pb.NewOrchestratorServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	stream, err := c.ProcessCommand(ctx, &pb.ProcessRequest{
		ClientId:    userId,
		MessageJson: string(message),
		CommandId:   commandId,
	})
	if err != nil {
		log.Printf("!!! [gRPC] Could not start command stream for user %s (commandId: %s): %v", userId, commandId, err)
		return
	}
	for {
		response, err := stream.Recv()
		if err == io.EOF {
			log.Printf("-> [gRPC] Stream closed by orchestrator for user %s (commandId: %s).", userId, commandId)
			break
		}
		if err != nil {
			log.Printf("!!! [gRPC] Error receiving message from stream for user %s (commandId: %s): %v", userId, commandId, err)
			break
		}
		var responsePayload map[string]interface{}
		if err := json.Unmarshal([]byte(response.GetMessage()), &responsePayload); err != nil {
			log.Printf("!!! [gRPC] Could not unmarshal response message from Python: %v", err)
			continue
		}
		responsePayload["commandId"] = response.GetCommandId()
		responseMessage, err := json.Marshal(responsePayload)
		if err != nil {
			log.Printf("!!! [gRPC] Could not marshal final response message: %v", err)
			continue
		}
		msgType, _ := responsePayload["type"].(string)
		switch msgType {
		case "confirmation_required", "status_update", "execution_result":
			log.Printf("--> [gRPC] Forwarding message of type '%s' to mobiles for user %s (commandId: %s)...", msgType, userId, commandId)
			cm.SendToMobilesOfUser(userId, responseMessage)
		default:
			log.Printf("--> [gRPC] Forwarding message of type '%s' to agents for user %s (commandId: %s)...", msgType, userId, commandId)
			cm.SendToAgentsOfUser(userId, responseMessage)
		}
	}
}

func handleConfirmation(userId string, message []byte) {
	var reqData struct {
		Approved bool   `json:"approved"`
		Intent   string `json:"intent"`
	}
	if err := json.Unmarshal(message, &reqData); err != nil {
		log.Printf("!!! [gRPC Conf] Could not unmarshal confirmation response: %v", err)
		return
	}
	addr := "orchestrator-py:50051"
	conn, err := grpc.NewClient(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Printf("!!! [gRPC Conf] Did not connect: %v", err)
		return
	}
	defer conn.Close()
	c := pb.NewOrchestratorServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_, err = c.HandleConfirmation(ctx, &pb.ConfirmationRequest{
		ClientId: userId,
		Approved: reqData.Approved,
		Intent:   reqData.Intent,
	})
	if err != nil {
		log.Printf("!!! [gRPC Conf] Could not handle confirmation for user %s: %v", userId, err)
	} else {
		log.Printf("-> [gRPC Conf] Successfully sent confirmation for user %s.", userId)
	}
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
			} else if conn.ClientType == "mobile" && msgType == "confirmation_response" {
				log.Printf("<- [ReadPump] Received confirmation from mobile (userId %s)", conn.UserId)
				go handleConfirmation(conn.UserId, p)
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
