package paymentapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	accountv1 "github.com/e2engine/demo/gen/account/v1"
	notificationv1 "github.com/e2engine/demo/gen/notification/v1"
)

type Server struct {
	fraudURL     string
	httpClient   *http.Client
	account      accountv1.AccountServiceClient
	notification notificationv1.NotificationServiceClient

	mu       sync.Mutex
	payments map[string]Payment
}

type Payment struct {
	ID        string `json:"paymentId"`
	AccountID string `json:"accountId"`
	Amount    int64  `json:"amount"`
	Currency  string `json:"currency"`
	Status    string `json:"status"`
}

type createPaymentRequest struct {
	AccountID string `json:"accountId"`
	Amount    int64  `json:"amount"`
	Currency  string `json:"currency"`
}

type fraudCheckRequest struct {
	AccountID string `json:"accountId"`
	Amount    int64  `json:"amount"`
	Currency  string `json:"currency"`
}

type fraudCheckResponse struct {
	Approved bool `json:"approved"`
}

type errorResponse struct {
	Error string `json:"error"`
}

func NewServer(
	fraudURL string,
	account accountv1.AccountServiceClient,
	notification notificationv1.NotificationServiceClient,
) *Server {
	return &Server{
		fraudURL:     fraudURL,
		httpClient:   http.DefaultClient,
		account:      account,
		notification: notification,
		payments:     make(map[string]Payment),
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /payments", s.createPayment)

	return mux
}

func (s *Server) createPayment(w http.ResponseWriter, r *http.Request) {
	var req createPaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{
			Error: "invalid request",
		})
		return
	}

	testExecutionID := r.Header.Get("E2Engine-Test-Execution-ID")

	if req.AccountID == "" || req.Amount <= 0 || req.Currency == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{
			Error: "invalid payment",
		})
		return
	}

	approved, err := s.checkFraud(r.Context(), req, testExecutionID)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, errorResponse{
			Error: "fraud service unavailable: " + err.Error(),
		})
		return
	}

	if !approved {
		writeJSON(w, http.StatusUnprocessableEntity, errorResponse{
			Error: "payment rejected",
		})
		return
	}

	const testExecutionIDKey = "e2engine-test-execution-id"
	callCtx := metadata.AppendToOutgoingContext(
		r.Context(),
		testExecutionIDKey,
		testExecutionID,
	)

	_, err = s.account.Debit(callCtx, &accountv1.DebitRequest{
		AccountId: req.AccountID,
		Amount:    req.Amount,
		Currency:  req.Currency,
	})
	if err != nil {
		if status.Code(err) == codes.FailedPrecondition {
			writeJSON(w, http.StatusUnprocessableEntity, errorResponse{
				Error: "payment rejected",
			})
			return
		}

		writeJSON(w, http.StatusBadGateway, errorResponse{
			Error: "account service unavailable",
		})
		return
	}

	paymentID := "payment-1"

	payment := Payment{
		ID:        paymentID,
		AccountID: req.AccountID,
		Amount:    req.Amount,
		Currency:  req.Currency,
		Status:    "completed",
	}

	s.mu.Lock()
	s.payments[paymentID] = payment
	s.mu.Unlock()

	_, _ = s.notification.Send(
		callCtx,
		&notificationv1.SendRequest{
			AccountId: req.AccountID,
			PaymentId: paymentID,
			Amount:    req.Amount,
			Currency:  req.Currency,
		},
	)

	writeJSON(w, http.StatusCreated, payment)
}

func (s *Server) checkFraud(
	ctx context.Context,
	payment createPaymentRequest,
	testExecutionID string,
) (bool, error) {
	body, err := json.Marshal(fraudCheckRequest{
		AccountID: payment.AccountID,
		Amount:    payment.Amount,
		Currency:  payment.Currency,
	})
	if err != nil {
		return false, err
	}

	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		s.fraudURL+"/check",
		bytes.NewReader(body),
	)
	if err != nil {
		return false, err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("E2Engine-Test-Execution-ID", testExecutionID)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf(
			"fraud service returned %s",
			resp.Status,
		)
	}

	var result fraudCheckResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return false, err
	}

	return result.Approved, nil
}

func writeJSON(w http.ResponseWriter, statusCode int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(value)
}
