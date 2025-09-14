package main

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type ConnectionManager struct {
	clients map[string]map[string]*Connection
	mutex   sync.Mutex
}

func NewConnectionManager() *ConnectionManager {
	return &ConnectionManager{
		clients: make(map[string]map[string]*Connection),
	}
}

func (cm *ConnectionManager) RegisterConnection(conn *Connection) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	if _, ok := cm.clients[conn.UserId]; !ok {
		cm.clients[conn.UserId] = make(map[string]*Connection)
	}
	cm.clients[conn.UserId][conn.ConnId] = conn
	log.Printf("-> [CM] New connection (id: %s, type: %s) registered for userId: %s", conn.ConnId, conn.ClientType, conn.UserId)

	if conn.ClientType == "agent" {
		cm.broadcastAgentStatusChange(conn.UserId, "ONLINE")
	}
}

func (cm *ConnectionManager) UnregisterConnection(conn *Connection) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	if userConnections, ok := cm.clients[conn.UserId]; ok {
		if _, ok := userConnections[conn.ConnId]; ok {
			clientType := conn.ClientType
			delete(userConnections, conn.ConnId)
			if len(userConnections) == 0 {
				delete(cm.clients, conn.UserId)
			}
			log.Printf("<- [CM] Connection (id: %s) for userId: %s closed.", conn.ConnId, conn.UserId)
			if clientType == "agent" {
				cm.broadcastAgentStatusChange(conn.UserId, "OFFLINE")
			}
		}
	}
}

func (cm *ConnectionManager) GetOnlineAgentDeviceIds(userId string) []string {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	var deviceIds []string
	if connections, found := cm.clients[userId]; found {
		for _, connWrapper := range connections {
			if connWrapper.ClientType == "agent" {
				deviceIds = append(deviceIds, connWrapper.DeviceId)
			}
		}
	}
	log.Printf("-> [CM] Found %d online agent(s) for userId: %s", len(deviceIds), userId)
	return deviceIds
}

func (cm *ConnectionManager) SendToAgentsOfUser(userId string, message []byte) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	if connections, found := cm.clients[userId]; found {
		agentCount := 0
		for _, connWrapper := range connections {
			if connWrapper.ClientType == "agent" {
				connWrapper.Conn.SetWriteDeadline(time.Now().Add(writeWait))
				if err := connWrapper.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
					log.Printf("!!! [CM] Error sending to agent %s for userId %s: %v", connWrapper.ConnId, userId, err)
				}
				agentCount++
			}
		}
		if agentCount > 0 {
			log.Printf("--> [CM] Dispatched message to %d agent(s) for userId: %s", agentCount, userId)
		} else {
			log.Printf("... [CM] No agents found for userId %s to send message to.", userId)
		}
	} else {
		log.Printf("!!! [CM] User %s has no active connections to send a message to.", userId)
	}
}

func (cm *ConnectionManager) SendToMobilesOfUser(userId string, message []byte) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	if connections, found := cm.clients[userId]; found {
		mobileCount := 0
		for _, connWrapper := range connections {
			if connWrapper.ClientType == "mobile" {
				connWrapper.Conn.SetWriteDeadline(time.Now().Add(writeWait))
				if err := connWrapper.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
					log.Printf("!!! [CM] Error sending to mobile %s for userId %s: %v", connWrapper.ConnId, userId, err)
				}
				mobileCount++
			}
		}
		if mobileCount > 0 {
			log.Printf("--> [CM] Dispatched result to %d mobile(s) for userId: %s", mobileCount, userId)
		}
	}
}

func (cm *ConnectionManager) broadcastAgentStatusChange(userId string, status string) {
	message := fmt.Sprintf(`{"type": "agent_status_changed", "status": "%s"}`, status)

	if connections, found := cm.clients[userId]; found {
		mobileCount := 0
		for _, connWrapper := range connections {
			if connWrapper.ClientType == "mobile" {
				connWrapper.Conn.SetWriteDeadline(time.Now().Add(writeWait))
				if err := connWrapper.Conn.WriteMessage(websocket.TextMessage, []byte(message)); err != nil {
					log.Printf("!!! [CM-Broadcast] Error broadcasting agent status to mobile %s: %v", connWrapper.ConnId, err)
				}
				mobileCount++
			}
		}
		if mobileCount > 0 {
			log.Printf("--> [CM-Broadcast] Broadcasted agent status '%s' to %d mobile(s) for userId: %s", status, mobileCount, userId)
		}
	}
}
