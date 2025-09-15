package main

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"time"

	pb "llm-remote-assistant/gateway/protos"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type OrchestratorClient struct {
	addr string
}

func NewOrchestratorClient(address string) *OrchestratorClient {
	return &OrchestratorClient{addr: address}
}

func (c *OrchestratorClient) ForwardCommandStream(cm *ConnectionManager, userId string, message []byte) {
	var requestData map[string]interface{}
	if err := json.Unmarshal(message, &requestData); err != nil {
		log.Printf("!!! [gRPC Client] Could not unmarshal incoming message for user %s: %v", userId, err)
		return
	}

	commandId, _ := requestData["commandId"].(string)
	if commandId == "" {
		log.Printf("!!! [gRPC Client] Missing commandId in request from user %s. Aborting.", userId)
		return
	}

	conn, err := grpc.NewClient(c.addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Printf("!!! [gRPC Client] Did not connect: %v", err)
		return
	}
	defer conn.Close()

	client := pb.NewOrchestratorServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	stream, err := client.ProcessCommand(ctx, &pb.ProcessRequest{
		ClientId:    userId,
		MessageJson: string(message),
		CommandId:   commandId,
	})
	if err != nil {
		log.Printf("!!! [gRPC Client] Could not start command stream for user %s (commandId: %s): %v", userId, commandId, err)
		return
	}

	for {
		response, err := stream.Recv()
		if err == io.EOF {
			log.Printf("-> [gRPC Client] Stream closed by orchestrator for user %s (commandId: %s).", userId, commandId)
			break
		}
		if err != nil {
			log.Printf("!!! [gRPC Client] Error receiving message from stream for user %s (commandId: %s): %v", userId, commandId, err)
			break
		}

		var responsePayload map[string]interface{}
		if err := json.Unmarshal([]byte(response.GetMessage()), &responsePayload); err != nil {
			log.Printf("!!! [gRPC Client] Could not unmarshal response message from Python: %v", err)
			continue
		}
		responsePayload["commandId"] = response.GetCommandId()

		responseMessage, err := json.Marshal(responsePayload)
		if err != nil {
			log.Printf("!!! [gRPC Client] Could not marshal final response message: %v", err)
			continue
		}

		msgType, _ := responsePayload["type"].(string)
		switch msgType {
		case "confirmation_required", "status_update", "execution_result":
			cm.SendToMobilesOfUser(userId, responseMessage)
		default:
			cm.SendToAgentsOfUser(userId, responseMessage)
		}
	}
}

func (c *OrchestratorClient) HandleConfirmation(userId string, message []byte) {
	var reqData struct {
		Approved bool   `json:"approved"`
		Intent   string `json:"intent"`
	}
	if err := json.Unmarshal(message, &reqData); err != nil {
		log.Printf("!!! [gRPC Client Conf] Could not unmarshal confirmation response: %v", err)
		return
	}

	conn, err := grpc.NewClient(c.addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Printf("!!! [gRPC Client Conf] Did not connect: %v", err)
		return
	}
	defer conn.Close()

	client := pb.NewOrchestratorServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err = client.HandleConfirmation(ctx, &pb.ConfirmationRequest{
		ClientId: userId,
		Approved: reqData.Approved,
		Intent:   reqData.Intent,
	})
	if err != nil {
		log.Printf("!!! [gRPC Client Conf] Could not handle confirmation for user %s: %v", userId, err)
	} else {
		log.Printf("-> [gRPC Client Conf] Successfully sent confirmation for user %s.", userId)
	}
}
