FROM ghcr.io/grafana/quickpizza-base:latest as build

WORKDIR /app

ENV PUBLIC_BACKEND_ENDPOINT=http://localhost:3333/
ENV PUBLIC_BACKEND_WS_ENDPOINT=ws://localhost:3333/
RUN go generate web/web.go 

ARG BACKEND_ENDPOINT=http://localhost:3333/
ARG BACKEND_WS_ENDPOINT=ws://localhost:3333/
ENV BACKEND_ENDPOINT=${BACKEND_ENDPOINT}
ENV BACKEND_WS_ENDPOINT=${BACKEND_WS_ENDPOINT}
RUN find ./web/build -type f -exec sed -i "s|http://localhost:3333/|$BACKEND_ENDPOINT|g" {} +
RUN find ./web/build -type f -exec sed -i "s|ws://localhost:3333/|$BACKEND_WS_ENDPOINT|g" {} +

RUN GO111MODULE=on CGO_ENABLED=0 go build -o bin/quickpizza


FROM gcr.io/distroless/static-debian11

COPY --from=build /app/bin/quickpizza /
COPY --from=build /app/data.json /data.json

ENTRYPOINT [ "./quickpizza" ]