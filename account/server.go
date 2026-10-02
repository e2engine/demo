package account

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	accountv1 "github.com/e2engine/demo/gen/account/v1"
)

type Server struct {
	accountv1.UnimplementedAccountServiceServer

	balances map[string]int64
}

func NewServer() *Server {
	return &Server{
		balances: map[string]int64{
			"acc-001": 100_000, // €1,000
			"acc-002": 5_000,   // €50
		},
	}
}

func (s *Server) Debit(
	_ context.Context,
	req *accountv1.DebitRequest,
) (*accountv1.DebitResponse, error) {
	balance, ok := s.balances[req.GetAccountId()]
	if !ok {
		return nil, status.Error(codes.NotFound, "account not found")
	}

	if req.GetCurrency() != "EUR" {
		return nil, status.Error(codes.InvalidArgument, "unsupported currency")
	}

	if req.GetAmount() <= 0 {
		return nil, status.Error(codes.InvalidArgument, "amount must be positive")
	}

	if balance < req.GetAmount() {
		return nil, status.Error(codes.FailedPrecondition, "insufficient funds")
	}

	return &accountv1.DebitResponse{
		TransactionId: "txn-1",
	}, nil
}
