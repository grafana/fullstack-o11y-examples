# Build context is ./services (single Go module for all three services).
FROM golang:1.25@sha256:d7ae6dbb143c4eb97788a53a2bfa879cdde91f793c1d44d9f3bc7cb0df2e4e5f AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /bin/app ./checkout

FROM gcr.io/distroless/static-debian12@sha256:6447365a6337c3732f412d1b74357b30a633831955b2bc45552b0086be907687
COPY --from=build /bin/app /app
EXPOSE 8002
ENTRYPOINT ["/app"]
