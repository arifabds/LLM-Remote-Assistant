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

// Dummy connection handler
func handleConnections(w http.ResponseWriter, r *http.Request) {

	fmt.Println("Gateway-go: WebSocket endpoint hit, but not upgrading yet.")

	fmt.Fprint(w, "Gateway-go is running. WebSocket connection point is here.")
}

func main() {
	// /ws paths redirect to handleConnections
	http.HandleFunc("/ws", handleConnections)

	fmt.Println("Gateway-go server starting on port 8080")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		// Error logging
		fmt.Printf("Error starting server: %s\n", err)
	}
}
