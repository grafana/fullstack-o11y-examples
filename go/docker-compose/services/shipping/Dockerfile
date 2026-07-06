# Build context is ./services (single Go module for all three services).
FROM golang:1.23 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /bin/app ./shipping

FROM gcr.io/distroless/static-debian12
COPY --from=build /bin/app /app
EXPOSE 8003
ENTRYPOINT ["/app"]
