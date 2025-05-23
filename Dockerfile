FROM node:23.10.0-bullseye AS fe-builder

WORKDIR /app/pkg/web
COPY pkg/web ./

# Define public endpoints. If empty (default), the frontend will use the hostname used to load the page.
ARG PUBLIC_BACKEND_ENDPOINT=""
ENV PUBLIC_BACKEND_ENDPOINT=${PUBLIC_BACKEND_ENDPOINT}
ARG PUBLIC_BACKEND_WS_ENDPOINT=""
ENV PUBLIC_BACKEND_WS_ENDPOINT=${PUBLIC_BACKEND_WS_ENDPOINT}

RUN npm install && \
    npm run build

FROM golang:1.24-bullseye AS builder

WORKDIR /app
COPY . ./
COPY --from=fe-builder /app/pkg/web/build /app/pkg/web/build
# Disable CGO in order to build a completely static binary, allowing us to use the binary in a container
# with uses a different distribution of libc.
RUN CGO_ENABLED=0 go build -o /bin/quickpizza ./cmd

FROM gcr.io/distroless/static-debian11

COPY --from=builder /bin/quickpizza /bin
EXPOSE 3333 3334 3335
ENTRYPOINT [ "/bin/quickpizza" ]
