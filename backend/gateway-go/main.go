package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"
)

var startTime = time.Now()

func init() {
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)
}

type SendMessageRequest struct {
	UserID  string `json:"userId"`
	Message string `json:"message"`
}

type NotifyRequest struct {
	UserID string `json:"userId"`
}

func main() {
	connectionManager := NewConnectionManager()

	publicMux := http.NewServeMux()
	publicMux.HandleFunc("/ws/connect", func(w http.ResponseWriter, r *http.Request) {
		handleConnections(connectionManager, w, r)
	})

	go func() {
		log.Println("-> [Main] Public server starting on 0.0.0.0:8080")
		if err := http.ListenAndServe("0.0.0.0:8080", publicMux); err != nil {
			log.Fatalf("!!! [Main] Failed to start public server: %v", err)
		}
	}()

	internalMux := http.NewServeMux()

	internalMux.HandleFunc("/internal/status/user/", func(w http.ResponseWriter, r *http.Request) {
		userId := strings.TrimPrefix(r.URL.Path, "/internal/status/user/")
		onlineAgentDeviceIds := connectionManager.GetOnlineAgentDeviceIds(userId)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(onlineAgentDeviceIds)
	})

	internalMux.HandleFunc("/internal/send-to-agent", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
			return
		}
		var req SendMessageRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		log.Printf("--> [Internal] Received request to send message to agent for userId: %s", req.UserID)
		connectionManager.SendToAgentsOfUser(req.UserID, []byte(req.Message))
		w.WriteHeader(http.StatusOK)
	})
	internalMux.HandleFunc("/internal/send-to-mobile", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
			return
		}
		var req SendMessageRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		log.Printf("--> [Internal] Received request to send message to mobile for userId: %s", req.UserID)
		connectionManager.SendToMobilesOfUser(req.UserID, []byte(req.Message))
		w.WriteHeader(http.StatusOK)
	})
	internalMux.HandleFunc("/internal/notify-pairing-complete", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
			return
		}
		var req NotifyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		log.Printf("[%dms] [LOG-P.2.1-GO-NOTIFY-RECV] Received request to notify pairing complete for userId: %s", time.Since(startTime).Milliseconds(), req.UserID)

		pairingCompleteMessage := `{"type": "pairing_complete"}`
		connectionManager.SendToAgentsOfUser(req.UserID, []byte(pairingCompleteMessage))

		w.WriteHeader(http.StatusOK)
	})
	internalMux.HandleFunc("/internal/notify-unpair", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
			return
		}
		var req NotifyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		log.Printf("[%dms] [LOG-P.14.1.2-GO-NOTIFY-RECV] Received request to notify unpair for userId: %s", time.Since(startTime).Milliseconds(), req.UserID)

		unpairedMessage := `{"type": "unpaired"}`
		connectionManager.SendToAgentsOfUser(req.UserID, []byte(unpairedMessage))

		w.WriteHeader(http.StatusOK)
	})

	log.Println("-> [Main] Internal server starting on 0.0.0.0:8081")
	if err := http.ListenAndServe("0.0.0.0:8081", internalMux); err != nil {
		log.Fatalf("!!! [Main] Failed to start internal server: %v", err)
	}
}
