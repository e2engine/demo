.PHONY:  protoc-account
protoc-account:
	@echo "Generating protobuf code for account service..."
	@protoc \
      --go_out=. \
      --go_opt=module=github.com/e2engine/demo \
      --go-grpc_out=. \
      --go-grpc_opt=module=github.com/e2engine/demo \
      proto/account.proto
	@echo "Protobuf code generated successfully for account service."

.PHONY:  protoc-notification
protoc-notification:
	@echo "Generating protobuf code for notification service..."
	@protoc \
      --go_out=. \
      --go_opt=module=github.com/e2engine/demo \
      --go-grpc_out=. \
      --go-grpc_opt=module=github.com/e2engine/demo \
      proto/notification.proto
	@echo "Protobuf code generated successfully for notification service."

.PHONY: protoc
protoc: protoc-account protoc-notification
	@echo "All protobuf code generated successfully."

.PHONY: demo-cli
demo-cli:
	@./scripts/demo-cli.sh

.PHONY: demo-ci
demo-ci:
	@./scripts/demo-ci.sh

ROOT_PATH := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
ACCOUNT_DIR := $(ROOT_PATH)account/bin
ACCOUNT_BINARY := $(ACCOUNT_DIR)/account
PAYMENT_API_DIR := $(ROOT_PATH)payment-api/bin
PAYMENT_API_BINARY := $(PAYMENT_API_DIR)/payment-api

.PHONY: account-service
account-service:
	@echo "Building account service..."
	mkdir -p $(ACCOUNT_DIR)
	go build -o $(ACCOUNT_BINARY) account/cmd/main.go
	echo "Starting account service..."
	$(ACCOUNT_BINARY)

.PHONY: payment-api-service
payment-api-service:
	@echo "Building payment API service..."
	mkdir -p $(PAYMENT_API_DIR)
	go build -o $(PAYMENT_API_BINARY) payment-api/cmd/main.go
	echo "Starting payment API service..."
	ACCOUNT_SERVICE_ADDR=localhost:8082 \
    NOTIFICATION_SERVICE_ADDR=localhost:8083 \
    FRAUD_SERVICE_URL=http://localhost:8081 \
    $(PAYMENT_API_BINARY)
