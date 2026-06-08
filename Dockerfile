# node:24-alpine
FROM node:24-alpine@sha256:2bdb65ed1dab192432bc31c95f94155ca5ad7fc1392fb7eb7526ab682fa5bf14 AS fe-builder

WORKDIR /app/pkg/web
COPY pkg/web ./

# Define public endpoints. If empty (default), the frontend will use the hostname used to load the page.
ARG PUBLIC_BACKEND_ENDPOINT=""
ENV PUBLIC_BACKEND_ENDPOINT=${PUBLIC_BACKEND_ENDPOINT}
ARG PUBLIC_BACKEND_WS_ENDPOINT=""
ENV PUBLIC_BACKEND_WS_ENDPOINT=${PUBLIC_BACKEND_WS_ENDPOINT}

RUN npm install && \
    npm run build

# golang:1.25-alpine
FROM golang:1.25-alpine@sha256:c05ba4b73604069d376c4f41346b05374335b5ca0c46fb6dfede5a59f5196931 AS builder

WORKDIR /app
COPY . ./
COPY --from=fe-builder /app/pkg/web/build /app/pkg/web/build
# Disable CGO in order to build a completely static binary, allowing us to use the binary in a container
# with uses a different distribution of libc.
RUN CGO_ENABLED=0 go build -o /bin/quickpizza ./cmd

# gcr.io/distroless/static-debian12
FROM gcr.io/distroless/static-debian12@sha256:9c346e4be81b5ca7ff31a0d89eaeade58b0f95cfd3baed1f36083ddb47ca3160

COPY --from=builder /bin/quickpizza /bin
EXPOSE 3333 3334 3335
ENTRYPOINT [ "/bin/quickpizza" ]
