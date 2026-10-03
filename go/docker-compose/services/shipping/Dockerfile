# Build context is ./services (single Go module for all three services).
FROM golang:1.27@sha256:e0174e51e81218523251d85d248a90d24c3d5e81543b4f07a5d66229397db190 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /bin/app ./shipping

FROM gcr.io/distroless/static-debian12@sha256:6447365a6337c3732f412d1b74357b30a633831955b2bc45552b0086be907687
COPY --from=build /bin/app /app
EXPOSE 8003
ENTRYPOINT ["/app"]
