FROM dgzlopes/quickpizza-again:base

WORKDIR /app

ARG PUBLIC_BACKEND_ENDPOINT=http://localhost:3333/
ENV PUBLIC_BACKEND_ENDPOINT=${PUBLIC_BACKEND_ENDPOINT}

RUN make build

ENTRYPOINT [ "./bin/quickpizza" ]