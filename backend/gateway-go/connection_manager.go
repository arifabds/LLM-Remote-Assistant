package main

import (
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type ConnectionManager struct {
	clients map[string]map[string]*Connection

	mutex sync.Mutex
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

	log.Printf("-> [CM] New connection (id: %s, type: %s) registered for userId: %s. Total for user: %d",
		conn.ConnId, conn.ClientType, conn.UserId, len(cm.clients[conn.UserId]))
}

func (cm *ConnectionManager) UnregisterConnection(conn *Connection) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	if userConnections, ok := cm.clients[conn.UserId]; ok {
		if _, ok := userConnections[conn.ConnId]; ok {
			delete(userConnections, conn.ConnId)

			if len(userConnections) == 0 {
				delete(cm.clients, conn.UserId)
				log.Printf("<- [CM] Last connection (id: %s) for userId: %s closed. User removed.",
					conn.ConnId, conn.UserId)
			} else {
				log.Printf("<- [CM] Connection (id: %s) for userId: %s closed. %d connections remaining.",
					conn.ConnId, conn.UserId, len(userConnections))
			}
		}
	}
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
