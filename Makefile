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