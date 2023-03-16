FROM ghcr.io/grafana/quickpizza-base:latest

WORKDIR /app

ARG PUBLIC_BACKEND_ENDPOINT=http://localhost:3333/
ENV PUBLIC_BACKEND_ENDPOINT=${PUBLIC_BACKEND_ENDPOINT}
ARG PUBLIC_BACKEND_WS_ENDPOINT=ws://localhost:3333/
ENV PUBLIC_BACKEND_WS_ENDPOINT=${PUBLIC_BACKEND_WS_ENDPOINT}

RUN make build

FROM ubuntu:20.04

WORKDIR /app

COPY --from=0 /app/bin/quickpizza /app/bin/quickpizza
COPY --from=0 /app/data.json /app/data.json

ENTRYPOINT [ "./bin/quickpizza" ]