package main

import (
	"crypto/rsa"
	"errors"
	"fmt"
	"log"
	"os"

	"github.com/golang-jwt/jwt/v5"
)

var verifyKey *rsa.PublicKey

func init() {
	keyData, err := os.ReadFile("keys/publicKey.pem")
	if err != nil {
		log.Fatalf("!!! [JWT Auth] Error reading public key: %v", err)
	}
	verifyKey, err = jwt.ParseRSAPublicKeyFromPEM(keyData)
	if err != nil {
		log.Fatalf("!!! [JWT Auth] Error parsing public key: %v", err)
	}
	log.Println("-> [JWT Auth] Public key loaded and parsed successfully.")
}

func parseAndValidateToken(tokenString string) (string, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return verifyKey, nil
	})

	if err != nil {
		return "", err
	}
	if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
		if sub, ok := claims["sub"].(string); ok {
			return sub, nil
		}
		return "", errors.New("sub claim (userId) not found in token")
	}
	return "", errors.New("invalid token")
}
