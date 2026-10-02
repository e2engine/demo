package main

import (
	"log"
	"net"

	"google.golang.org/grpc"

	"github.com/e2engine/demo/account"
	accountv1 "github.com/e2engine/demo/gen/account/v1"
)

func main() {
	listener, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatal(err)
	}

	server := grpc.NewServer()
	accountv1.RegisterAccountServiceServer(server, account.NewServer())

	log.Println("account service listening on :50051")

	if err := server.Serve(listener); err != nil {
		log.Fatal(err)
	}
}
