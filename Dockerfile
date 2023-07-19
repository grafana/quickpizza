FROM node:16.19.1-bullseye as fe-builder

WORKDIR /app/pkg/web
COPY pkg/web ./

# Define public endpoints. If empty (default), the frontend will use the hostname used to load the page.
ARG PUBLIC_BACKEND_ENDPOINT=""
ENV PUBLIC_BACKEND_ENDPOINT=${PUBLIC_BACKEND_ENDPOINT}
ARG PUBLIC_BACKEND_WS_ENDPOINT=""
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
COPY data.json .

EXPOSE 3333
ENTRYPOINT [ "/bin/quickpizza" ]
