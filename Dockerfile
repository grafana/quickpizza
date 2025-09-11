FROM node:24-bullseye@sha256:1f01014be94e1bbd6687191b5e33e376b8bb1a48abf9c42560a26c812587fdfb AS fe-builder

WORKDIR /app/pkg/web
COPY pkg/web ./

# Define public endpoints. If empty (default), the frontend will use the hostname used to load the page.
ARG PUBLIC_BACKEND_ENDPOINT=""
ENV PUBLIC_BACKEND_ENDPOINT=${PUBLIC_BACKEND_ENDPOINT}
ARG PUBLIC_BACKEND_WS_ENDPOINT=""
ENV PUBLIC_BACKEND_WS_ENDPOINT=${PUBLIC_BACKEND_WS_ENDPOINT}

RUN npm install && \
    npm run build

FROM golang:1.24-bullseye@sha256:2cdc80dc25edcb96ada1654f73092f2928045d037581fa4aa7c40d18af7dd85a AS builder

WORKDIR /app
COPY . ./
COPY --from=fe-builder /app/pkg/web/build /app/pkg/web/build
# Disable CGO in order to build a completely static binary, allowing us to use the binary in a container
# with uses a different distribution of libc.
RUN CGO_ENABLED=0 go build -o /bin/quickpizza ./cmd

FROM gcr.io/distroless/static-debian11@sha256:1dbe426d60caed5d19597532a2d74c8056cd7b1674042b88f7328690b5ead8ed

COPY --from=builder /bin/quickpizza /bin
EXPOSE 3333 3334 3335
ENTRYPOINT [ "/bin/quickpizza" ]
