package main

import (
	"log"
	"net/http"
)

func main() {
	connectionManager := NewConnectionManager()

	http.HandleFunc("/ws/connect", func(w http.ResponseWriter, r *http.Request) {
		handleConnections(connectionManager, w, r)
	})

	log.Println("-> [Main] Public server starting on 0.0.0.0:8080")
	if err := http.ListenAndServe("0.0.0.0:8080", nil); err != nil {
		log.Fatalf("!!! [Main] Failed to start public server: %v", err)
	}
}
