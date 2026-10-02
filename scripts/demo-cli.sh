#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

E2ENGINE_DIR="${ROOT_DIR}/e2engine"

ACCOUNT_BIN="${ROOT_DIR}/account/bin/account"
PAYMENT_BIN="${ROOT_DIR}/payment-api/bin/payment-api"

ACCOUNT_PID=""
PAYMENT_PID=""

cleanup() {
    if [[ -n "${ACCOUNT_PID}" ]]; then
        kill "${ACCOUNT_PID}" 2>/dev/null || true
        echo "Stopped account service (PID: ${ACCOUNT_PID})"
    fi

    if [[ -n "${PAYMENT_PID}" ]]; then
        kill "${PAYMENT_PID}" 2>/dev/null || true
        echo "Stopped payment service (PID: ${PAYMENT_PID})"
    fi

    rm -f \
        "${ACCOUNT_BIN}" \
        "${PAYMENT_BIN}" \
        "${E2ENGINE_DIR}/config.yml" \
        "${E2ENGINE_DIR}/e2engine.sqlite"
}

trap cleanup EXIT INT TERM

cd "${ROOT_DIR}"

if ! command -v e2engine >/dev/null 2>&1; then
    echo "e2engine is not installed or not available in PATH."
    exit 1
fi

echo "Building demo services..."

mkdir -p "$(dirname "${ACCOUNT_BIN}")"
mkdir -p "$(dirname "${PAYMENT_BIN}")"

go build -o "${ACCOUNT_BIN}" ./account/cmd/main.go
go build -o "${PAYMENT_BIN}" ./payment-api/cmd/main.go

echo "Starting account service..."

"${ACCOUNT_BIN}" &
ACCOUNT_PID=$!

echo "Starting payment API service..."

ACCOUNT_SERVICE_ADDR=localhost:8082 \
NOTIFICATION_SERVICE_ADDR=localhost:8083 \
FRAUD_SERVICE_URL=http://localhost:8081 \
"${PAYMENT_BIN}" &
PAYMENT_PID=$!

sleep 5

if ! kill -0 "${ACCOUNT_PID}" 2>/dev/null; then
    echo "Account service failed to start."
    exit 1
fi

if ! kill -0 "${PAYMENT_PID}" 2>/dev/null; then
    echo "Payment API failed to start."
    exit 1
fi

echo "Executing E2Engine CLI commands..."

touch "${E2ENGINE_DIR}/config.yml"

export E2ENGINE_CONFIG_PATH="${E2ENGINE_DIR}/config.yml"
export E2ENGINE_DATA_DIR="${E2ENGINE_DIR}"

e2engine create env \
    "${E2ENGINE_DIR}/payment-demo.env.yml"

e2engine create test \
    "${E2ENGINE_DIR}/successful-payment.test.yml"

e2engine create test \
    "${E2ENGINE_DIR}/fraud-rejection.test.yml"

e2engine create test \
    "${E2ENGINE_DIR}/account-rejection.test.yml"

e2engine create ts \
    "${E2ENGINE_DIR}/smoke.ts.yml"

e2engine run ts smoke payment-demo

echo "Test suite executions:"

e2engine get testsuiteexecutions

echo "Test executions:"

e2engine get testexecutions