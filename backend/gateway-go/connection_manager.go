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
	log.Printf("[%dms] [LOG-GO-CM-INIT] New ConnectionManager created.", time.Since(startTime).Milliseconds())
	return &ConnectionManager{
		clients: make(map[string]map[string]*Connection),
	}
}

func (cm *ConnectionManager) RegisterConnection(conn *Connection) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	log.Printf("[%dms] [LOG-GO-CM-REGISTER-START] RegisterConnection called for userId: %s, connId: %s, clientType: %s, deviceId: %s", time.Since(startTime).Milliseconds(), conn.UserId, conn.ConnId, conn.ClientType, conn.DeviceId)

	if _, ok := cm.clients[conn.UserId]; !ok {
		cm.clients[conn.UserId] = make(map[string]*Connection)
		log.Printf("[%dms] [LOG-GO-CM-REGISTER-NEW-USER] First connection for user %s. Creating new map entry.", time.Since(startTime).Milliseconds(), conn.UserId)
	}
	cm.clients[conn.UserId][conn.ConnId] = conn
	log.Printf("[%dms] [LOG-GO-CM-REGISTER-SUCCESS] Connection %s registered. User %s now has %d active connection(s).", time.Since(startTime).Milliseconds(), conn.ConnId, conn.UserId, len(cm.clients[conn.UserId]))

	if conn.ClientType == "agent" {
		log.Printf("[%dms] [LOG-GO-CM-REGISTER-AGENT-DETECTED] Registered connection is an AGENT. Broadcasting ONLINE status.", time.Since(startTime).Milliseconds())
		cm.broadcastAgentStatusChange(conn.UserId, "ONLINE")
	}
}

func (cm *ConnectionManager) UnregisterConnection(conn *Connection) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	log.Printf("[%dms] [LOG-GO-CM-UNREGISTER-START] UnregisterConnection called for userId: %s, connId: %s", time.Since(startTime).Milliseconds(), conn.UserId, conn.ConnId)

	if userConnections, ok := cm.clients[conn.UserId]; ok {
		if _, clientFound := userConnections[conn.ConnId]; clientFound {
			clientType := conn.ClientType
			delete(userConnections, conn.ConnId)
			log.Printf("[%dms] [LOG-GO-CM-UNREGISTER-DELETED] Deleted connection %s. User %s now has %d remaining connection(s).", time.Since(startTime).Milliseconds(), conn.ConnId, conn.UserId, len(userConnections))
			if len(userConnections) == 0 {
				delete(cm.clients, conn.UserId)
				log.Printf("[%dms] [LOG-GO-CM-UNREGISTER-USER-REMOVED] User %s has no connections left. Removed user from map.", time.Since(startTime).Milliseconds(), conn.UserId)
			}
			if clientType == "agent" {
				log.Printf("[%dms] [LOG-GO-CM-UNREGISTER-AGENT-DETECTED] Unregistered connection was an AGENT. Broadcasting OFFLINE status.", time.Since(startTime).Milliseconds())
				cm.broadcastAgentStatusChange(conn.UserId, "OFFLINE")
			}
		} else {
			log.Printf("[%dms] [LOG-GO-CM-UNREGISTER-WARN] Connection %s not found for user %s. Unregister called for an already removed connection?", time.Since(startTime).Milliseconds(), conn.ConnId, conn.UserId)
		}
	} else {
		log.Printf("[%dms] [LOG-GO-CM-UNREGISTER-WARN] User %s not found in connection map. Unregister called for an unknown user?", time.Since(startTime).Milliseconds(), conn.UserId)
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
	log.Printf("[%dms] [LOG-GO-CM-GET-AGENTS] Found %d online agent(s) for userId: %s", time.Since(startTime).Milliseconds(), len(deviceIds), userId)
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
	log.Printf("[%dms] [LOG-GO-CM-BROADCAST-START] Broadcasting agent status '%s' for userId: %s.", time.Since(startTime).Milliseconds(), status, userId)

	if connections, found := cm.clients[userId]; found {
		mobileCount := 0
		for _, connWrapper := range connections {
			if connWrapper.ClientType == "mobile" {
				log.Printf("[%dms] [LOG-GO-CM-BROADCAST-SENDING] Found mobile client (connId: %s). Sending status update.", time.Since(startTime).Milliseconds(), connWrapper.ConnId)
				connWrapper.Conn.SetWriteDeadline(time.Now().Add(writeWait))
				if err := connWrapper.Conn.WriteMessage(websocket.TextMessage, []byte(message)); err != nil {
					log.Printf("!!! [CM-Broadcast] Error broadcasting agent status to mobile %s: %v", connWrapper.ConnId, err)
				}
				mobileCount++
			}
		}
		if mobileCount > 0 {
			log.Printf("[%dms] [LOG-GO-CM-BROADCAST-SUCCESS] Broadcasted to %d mobile(s).", time.Since(startTime).Milliseconds(), mobileCount)
		} else {
			log.Printf("[%dms] [LOG-GO-CM-BROADCAST-NO-MOBILES] No mobile clients found for user %s to broadcast to.", time.Since(startTime).Milliseconds(), userId)
		}
	} else {
		log.Printf("[%dms] [LOG-GO-CM-BROADCAST-NO-USER] User %s not found in map. Cannot broadcast.", time.Since(startTime).Milliseconds(), userId)
	}
}
