package grpc

import (
	"context"
	"fmt"
	"log/slog"
	"net"

	pb "github.com/grafana/quickpizza/pkg/grpc/quickpizza"
	"google.golang.org/grpc"
)

type serverImplementation struct {
	pb.UnimplementedGRPCServer
}

type Server struct {
	grpcServer *grpc.Server
	listen     string
}

func (s *serverImplementation) Status(_ context.Context, in *pb.StatusRequest) (*pb.StatusResponse, error) {
	return &pb.StatusResponse{Ready: true}, nil
}

func (s *serverImplementation) EvaluatePizza(_ context.Context, in *pb.PizzaEvaluationRequest) (*pb.PizzaEvaluationResponse, error) {
	return &pb.PizzaEvaluationResponse{}, nil
}

func NewServer(listen string) *Server {
	s := grpc.NewServer()
	pb.RegisterGRPCServer(s, &serverImplementation{})

	return &Server{grpcServer: s, listen: listen}
}

func (s *Server) ListenAndServe() error {
	lis, err := net.Listen("tcp", s.listen)
	if err != nil {
		return fmt.Errorf("failed to listen on port: %w", err)
	}

	slog.Info("Starting QuickPizza gRPC", "listenAddress", s.listen)
	return s.grpcServer.Serve(lis)
}
