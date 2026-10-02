#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NETWORK="e2engine-network"
DATA_DIR="${ROOT_DIR}/.e2engine"

E2ENGINE_VERSION="${E2ENGINE_VERSION:-0.1.0}"
E2ENGINE_IMAGE="ghcr.io/e2engine/cli:${E2ENGINE_VERSION}"

ACCOUNT_BIN="${ROOT_DIR}/account/bin/account"
PAYMENT_BIN="${ROOT_DIR}/payment-api/bin/payment-api"

ACCOUNT_SERVICE_NAME="account"
PAYMENT_API_NAME="payment-api"

ACCOUNT_SERVICE_IMAGE="e2engine-demo-account:local"
PAYMENT_API_IMAGE="e2engine-demo-payment-api:local"

cleanup() {
    docker rm -f \
        "${PAYMENT_API_NAME}" \
        "${ACCOUNT_SERVICE_NAME}" \
        >/dev/null 2>&1 || true

    docker network rm "${NETWORK}" >/dev/null 2>&1 || true

    rm -rf "${DATA_DIR}"

    rm -f \
            "${ACCOUNT_BIN}" \
            "${PAYMENT_BIN}"
}

trap cleanup EXIT

cd "${ROOT_DIR}"

echo "Building demo services..."

mkdir -p "$(dirname "${ACCOUNT_BIN}")"
mkdir -p "$(dirname "${PAYMENT_BIN}")"

DOCKER_ARCH="$(docker version --format '{{.Server.Arch}}')"

case "${DOCKER_ARCH}" in
    amd64|arm64)
        ;;
    *)
        echo "Unsupported Docker architecture: ${DOCKER_ARCH}"
        exit 1
        ;;
esac

CGO_ENABLED=0 GOOS=linux GOARCH="${DOCKER_ARCH}" \
    go build -o "${ACCOUNT_BIN}" ./account/cmd/main.go

CGO_ENABLED=0 GOOS=linux GOARCH="${DOCKER_ARCH}" \
    go build -o "${PAYMENT_BIN}" ./payment-api/cmd/main.go

docker buildx build \
    --platform "linux/${DOCKER_ARCH}" \
    --load \
    -t "${ACCOUNT_SERVICE_IMAGE}" \
    ./account

docker buildx build \
    --platform "linux/${DOCKER_ARCH}" \
    --load \
    -t "${PAYMENT_API_IMAGE}" \
    ./payment-api

echo "Creating Docker network..."

docker network create "${NETWORK}" >/dev/null

echo "Starting account service..."

docker run \
    -d \
    --name "${ACCOUNT_SERVICE_NAME}" \
    --network "${NETWORK}" \
    "${ACCOUNT_SERVICE_IMAGE}" \
    >/dev/null

echo "Starting payment API..."

docker run \
    -d \
    --name "${PAYMENT_API_NAME}" \
    --network "${NETWORK}" \
    -e ACCOUNT_SERVICE_ADDR=e2engine:8082 \
    -e NOTIFICATION_SERVICE_ADDR=e2engine:8083 \
    -e FRAUD_SERVICE_URL=http://e2engine:8081 \
    "${PAYMENT_API_IMAGE}" \
    >/dev/null

mkdir -p "${DATA_DIR}"

run_e2engine() {
    docker run \
        --rm \
        --name e2engine \
        --network "${NETWORK}" \
        -v "${DATA_DIR}:/data" \
        -v "${ROOT_DIR}/e2engine:/specs:ro" \
        -v "${ROOT_DIR}/proto:/proto:ro" \
        -e E2ENGINE_DATA_DIR=/data \
        "${E2ENGINE_IMAGE}" \
        "$@"
}

echo "Creating E2Engine environment..."

run_e2engine create env /specs/payment-demo.docker.env.yml

echo "Creating E2Engine tests..."

run_e2engine create test /specs/successful-payment.docker.test.yml
run_e2engine create test /specs/account-rejection.docker.test.yml
run_e2engine create test /specs/fraud-rejection.docker.test.yml

echo "Creating E2Engine test suite..."

run_e2engine create ts /specs/smoke.ts.yml

echo "Running test suite..."

tid=$(run_e2engine run ts smoke payment-demo -q)

if ! run_e2engine check tse "${tid}" -q; then
    echo "Test suite failed."
    run_e2engine get tse "${tid}"
    exit 1
fi

echo "Test suite executions:"

run_e2engine get testsuiteexecutions

echo "Test executions:"

run_e2engine get testexecutions

echo "E2E tests passed."