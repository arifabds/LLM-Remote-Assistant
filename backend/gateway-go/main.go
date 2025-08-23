package main

import (
	"fmt"
	"net/http"

	"sync"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// Clients map
var clients = make(map[string]*websocket.Conn)

// Clients map mutex
var clientsMutex = sync.Mutex{}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		fmt.Printf("Error upgrading to websocket: %s\n", err)
		return
	}

	defer ws.Close()

	fmt.Println("Gateway-go: Client successfully connected via WebSocket")
}

func main() {
	// /ws paths redirect to handleConnections
	http.HandleFunc("/ws/connect", handleConnections)

	fmt.Println("Gateway-go server starting on port 8080")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		// Error logging
		fmt.Printf("Error starting server: %s\n", err)
	}
}
