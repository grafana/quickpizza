FROM node:16.19.1-bullseye as fe-builder

WORKDIR /app/pkg/web
COPY pkg/web ./

# TODO: Allow reading these vars in runtime.
ARG PUBLIC_BACKEND_ENDPOINT=http://localhost:3333/
ENV PUBLIC_BACKEND_ENDPOINT=${PUBLIC_BACKEND_ENDPOINT}
ARG PUBLIC_BACKEND_WS_ENDPOINT=ws://localhost:3333/
ENV PUBLIC_BACKEND_WS_ENDPOINT=${PUBLIC_BACKEND_WS_ENDPOINT}

RUN npm install && \
    npm run build

FROM golang:1.20-bullseye as builder

WORKDIR /app
COPY . ./
COPY --from=fe-builder /app/pkg/web/build /app/pkg/web/build
RUN go generate pkg/web/web.go && \
    GO111MODULE=on CGO_ENABLED=0 go build -o /bin/quickpizza ./cmd

FROM gcr.io/distroless/static-debian11

COPY --from=builder /bin/quickpizza /bin
COPY data.json /

# Serve all microservices by default
ENV QP_ALL_SERVICES=1

EXPOSE 3333
ENTRYPOINT [ "/bin/quickpizza" ]
