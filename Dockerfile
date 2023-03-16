FROM ghcr.io/grafana/quickpizza-base:latest as build

WORKDIR /app

ARG PUBLIC_BACKEND_ENDPOINT=http://localhost:3333/
ENV PUBLIC_BACKEND_ENDPOINT=${PUBLIC_BACKEND_ENDPOINT}
ARG PUBLIC_BACKEND_WS_ENDPOINT=ws://localhost:3333/
ENV PUBLIC_BACKEND_WS_ENDPOINT=${PUBLIC_BACKEND_WS_ENDPOINT}

RUN go generate web/web.go 

RUN GO111MODULE=on CGO_ENABLED=0 go build -o bin/quickpizza

FROM gcr.io/distroless/static-debian11

COPY --from=build /app/bin/quickpizza /
COPY --from=build /app/data.json /data.json

ENTRYPOINT [ "./quickpizza" ]