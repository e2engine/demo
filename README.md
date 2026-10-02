# E2Engine Demo

A small application demonstrating how E2Engine describes, executes, and verifies tests across real and mocked services.

The demo combines HTTP and gRPC services, real and mocked dependencies, response verification, and downstream call expectations in one executable test environment.

## What this demonstrates

The purpose of this repository is not the payment application itself. The application is intentionally small so the distributed test model remains visible.

The demo shows how E2Engine can describe a test environment containing multiple protocols and service modes, execute tests against a real application, and verify both observable responses and interactions between services.

Instead of assembling separate mock servers, proxy configuration, test orchestration, and interaction assertions in application test code, the environment and expected behavior are expressed as E2Engine resources.

## Architecture

```text
Payment API
    │
    ├── HTTP ──▶ Fraud Service          mocked by E2Engine
    │
    ├── gRPC ──▶ Account Service        real service
    │
    └── gRPC ──▶ Notification Service   mocked by E2Engine
```

The Payment API is the system under test.

E2Engine provides the mocked Fraud and Notification services and routes calls to the real Account service. This allows the tests to verify both the final HTTP response and the interactions between services.

## Payment flow

```text
POST /payments

1. Fraud Service checks the payment
2. Account Service debits the account
3. Payment API saves the payment
4. Notification Service receives the payment notification
5. Payment API returns the result
```

For a successful payment, all three downstream services are called. Rejected payments demonstrate that E2Engine can also verify that later services were not called.

## E2Engine environment

The demo environment is defined in `e2engine/payment-demo.env.yml`.

It demonstrates three service configurations:

- a mocked HTTP Fraud service with response fixtures;
- a real gRPC Account service using an external protobuf definition;
- a mocked gRPC Notification service whose protobuf contract is defined directly in the E2Engine environment.

The Payment API communicates with the E2Engine service addresses rather than directly with its dependencies. E2Engine can therefore route and observe the interactions during each test execution.

## Tests

The repository contains three tests.

### Successful payment

```text
✓ Fraud /check called once
✓ AccountService.Debit called once
✓ NotificationService.Send called once
✓ HTTP response = 201
```

### Fraud rejection

```text
✓ Fraud /check called once
✓ AccountService.Debit not called
✓ NotificationService.Send not called
✓ HTTP response = 422
```

### Account rejection

```text
✓ Fraud /check called once
✓ AccountService.Debit called once
✓ NotificationService.Send not called
✓ HTTP response = 422
```

All three tests are tagged `smoke` and selected by `e2engine/smoke.ts.yml`.

## Run the demo

The repository demonstrates two ways of running the same E2Engine environment, tests, and test suite:

- **CLI demo** — runs the application services locally and executes the tests using an installed E2Engine CLI.
- **CI/Docker demo** — runs the application services in Docker and executes the tests using the published E2Engine container image.

Both scenarios create the same environment, the same three tests, and the same `smoke` test suite. They differ only in how the application services and E2Engine are executed and addressed.

### CLI demo

The CLI demo requires the E2Engine CLI to be installed and available as `e2engine` in `PATH`.

Install the CLI using one of the methods described in the [E2Engine CLI repository README Installation section](https://github.com/e2engine/cli#installation), then verify the installation with:

```bash
e2engine version
```

Run the demo with:

```bash
make demo-cli
```

The CLI demo:

1. builds and starts the real Account service locally;
2. builds and starts the Payment API locally;
3. creates the E2Engine environment;
4. creates the three tests;
5. creates the `smoke` test suite;
6. executes and verifies the suite using the installed E2Engine CLI;
7. cleans up the demo processes and local E2Engine state.

### CI/Docker demo

The CI/Docker demo requires Docker with Buildx support. It does not require the E2Engine CLI to be installed locally; E2Engine runs from the published `ghcr.io/e2engine/cli` container image.

Run the demo with:

```bash
make demo-ci
```

The CI/Docker demo:

1. builds Linux binaries and Docker images for the real Account service and Payment API;
2. creates an isolated Docker network and starts both application services on it;
3. runs E2Engine from its published container image on the same network;
4. creates the E2Engine environment;
5. creates the three tests and the `smoke` test suite;
6. executes and verifies the suite using the E2Engine container;
7. cleans up the containers, Docker network, generated binaries, and E2Engine state.

The repository also contains a manually triggered GitHub Actions workflow that runs the CI/Docker demo, providing an example of using E2Engine in CI.

A successful run of either demo creates a test-suite execution containing all three passing test executions.

## Test scenarios

| Scenario           | Fraud  | Account                       | Notification | Response |
|--------------------|--------|-------------------------------|--------------|----------|
| Successful payment | 1 call | 1 call / OK                   | 1 call       | 201      |
| Fraud rejection    | 1 call | 0 calls                       | 0 calls      | 422      |
| Account rejection  | 1 call | 1 call / `FailedPrecondition` | 0 calls      | 422      |

## Repository structure

```text
e2engine-demo/
├── account/            # real gRPC Account service
├── payment-api/        # HTTP system under test
├── proto/              # protobuf definitions used by the demo application
├── gen/                # generated Go protobuf code
├── e2engine/           # E2Engine environment, test, and testsuite specs
├── scripts/            # local CLI and CI/Docker demo scripts
├── Makefile
└── README.md
```

## E2Engine

This repository is part of E2Engine.

- [core](https://github.com/e2engine/core) — core domain model, execution logic, and public APIs
- [repository](https://github.com/e2engine/repository) — persistence implementations
- [runner-local](https://github.com/e2engine/runner-local) — local test execution
- [cli](https://github.com/e2engine/cli) — command-line interface
- [tests](https://github.com/e2engine/tests) — end-to-end tests for E2Engine
- [demo](https://github.com/e2engine/demo) — executable demonstration system and E2Engine usage examples

## License

Licensed under the Apache License, Version 2.0.