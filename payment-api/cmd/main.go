package main

import (
	"log"
	"net/http"
	"os"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	e2enginegrpc "github.com/e2engine/instrumentation-go/grpc"

	accountv1 "github.com/e2engine/demo/gen/account/v1"
	notificationv1 "github.com/e2engine/demo/gen/notification/v1"
	paymentapi "github.com/e2engine/demo/payment-api"
)

const (
	defaultHTTPAddr = ":8080"
)

func main() {
	accountAddr := mustEnv("ACCOUNT_SERVICE_ADDR")
	notificationAddr := mustEnv("NOTIFICATION_SERVICE_ADDR")
	fraudURL := mustEnv("FRAUD_SERVICE_URL")

	accountConn, err := grpc.NewClient(
		accountAddr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithUnaryInterceptor(
			e2enginegrpc.UnaryClientInterceptor(),
		),
	)
	if err != nil {
		log.Fatal(err)
	}
	defer accountConn.Close()

	notificationConn, err := grpc.NewClient(
		notificationAddr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithUnaryInterceptor(
			e2enginegrpc.UnaryClientInterceptor(),
		),
	)
	if err != nil {
		log.Fatal(err)
	}
	defer notificationConn.Close()

	server := paymentapi.NewServer(
		fraudURL,
		accountv1.NewAccountServiceClient(accountConn),
		notificationv1.NewNotificationServiceClient(notificationConn),
	)

	log.Printf("payment API listening on %s", defaultHTTPAddr)

	if err := http.ListenAndServe(defaultHTTPAddr, server.Handler()); err != nil {
		log.Fatal(err)
	}
}

func mustEnv(name string) string {
	value := os.Getenv(name)
	if value == "" {
		log.Fatalf("%s is required", name)
	}

	return value
}
