package main

import (
	"log"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

type ConnectionManager struct {
	clients map[string]map[*websocket.Conn]string
	mutex   sync.Mutex
}

func NewConnectionManager() *ConnectionManager {
	return &ConnectionManager{
		clients: make(map[string]map[*websocket.Conn]string),
	}
}

func (cm *ConnectionManager) RegisterConnection(userId string, conn *websocket.Conn) string {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	if _, ok := cm.clients[userId]; !ok {
		cm.clients[userId] = make(map[*websocket.Conn]string)
	}

	connectionId := uuid.New().String()
	cm.clients[userId][conn] = connectionId

	log.Printf("-> [CM] New connection (id: %s) registered for userId: %s. Total for user: %d",
		connectionId, userId, len(cm.clients[userId]))

	return connectionId
}

func (cm *ConnectionManager) UnregisterConnection(userId string, conn *websocket.Conn) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	if userConnections, ok := cm.clients[userId]; ok {
		connectionId := userConnections[conn]
		delete(userConnections, conn)

		if len(userConnections) == 0 {
			delete(cm.clients, userId)
			log.Printf("<- [CM] Last connection (id: %s) for userId: %s closed. User removed.",
				connectionId, userId)
		} else {
			log.Printf("<- [CM] Connection (id: %s) for userId: %s closed. %d connections remaining.",
				connectionId, userId, len(userConnections))
		}
	}
}

func (cm *ConnectionManager) BroadcastToUser(userId string, message []byte) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	if connections, found := cm.clients[userId]; found {
		log.Printf("--> [CM] Broadcasting to %d connections for userId: %s", len(connections), userId)
		for conn := range connections {
			err := conn.WriteMessage(websocket.TextMessage, message)
			if err != nil {
				log.Printf("!!! [CM] Error broadcasting to a connection for userId %s: %v", userId, err)
			}
		}
	} else {
		log.Printf("!!! [CM] User %s has no active connections to broadcast to.", userId)
	}
}
