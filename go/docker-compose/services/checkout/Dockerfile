# Build context is ./services (single Go module for all three services).
FROM golang:1.26@sha256:45a5f7a810238aabcbad211d70b9ae082022d96f7c7259e94041ad1b933575ac AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /bin/app ./checkout

FROM gcr.io/distroless/static-debian12@sha256:6447365a6337c3732f412d1b74357b30a633831955b2bc45552b0086be907687
COPY --from=build /bin/app /app
EXPOSE 8002
ENTRYPOINT ["/app"]
