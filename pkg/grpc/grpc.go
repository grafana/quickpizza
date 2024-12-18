package grpc

import (
	"context"
	"fmt"
	"log/slog"
	"math/rand"
	"net"
	"net/http"

	pb "github.com/grafana/quickpizza/pkg/grpc/quickpizza"
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
	"google.golang.org/grpc"
)

type serverImplementation struct {
	pb.UnimplementedGRPCServer
}

type Server struct {
	grpcServer    *grpc.Server
	listen        string
	healthzListen string
}

func (s *serverImplementation) Status(_ context.Context, in *pb.StatusRequest) (*pb.StatusResponse, error) {
	return &pb.StatusResponse{Ready: true}, nil
}

func (s *serverImplementation) RatePizza(_ context.Context, in *pb.PizzaRatingRequest) (*pb.PizzaRatingResponse, error) {
	var rating int32
	if len(in.Ingredients) > 0 {
		rating = rand.Int31n(6)
	}
	if in.Dough != "" && rating < 5 {
		rating += rand.Int31n(2)
	}
	return &pb.PizzaRatingResponse{
		StarsRating: rating,
	}, nil
}

func NewServer(listen string, healthzListen string) *Server {
	s := grpc.NewServer()
	pb.RegisterGRPCServer(s, &serverImplementation{})

	return &Server{grpcServer: s, listen: listen, healthzListen: healthzListen}
}

func (s *Server) listenHealthz() {
	mux := http.NewServeMux()
	mux.HandleFunc("/grpchealthz", func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("grpc-status", "12")
		w.Header().Set("grpc-message", "unimplemented")
		w.WriteHeader(http.StatusNoContent)
	})

	health := &http.Server{
		Addr:    s.healthzListen,
		Handler: h2c.NewHandler(mux, &http2.Server{}),
	}

	slog.Info("Starting QuickPizza gRPC health check server", "listenAddress", s.healthzListen)
	if err := health.ListenAndServe(); err != nil {
		slog.Error("Error listening for gRPC health check server", "err", err)
	}
}

func (s *Server) ListenAndServe() error {
	lis, err := net.Listen("tcp", s.listen)
	if err != nil {
		return fmt.Errorf("failed to listen on port: %w", err)
	}

	go s.listenHealthz()

	slog.Info("Starting QuickPizza gRPC server", "listenAddress", s.listen)
	return s.grpcServer.Serve(lis)
}
