# Build context is ./services (single Go module for all three services).
FROM golang:1.27@sha256:512690a5660563b57d37ecc31129e7f136e831db2aed24a1dbeb8ad7380dc0fa AS build
ARG SERVICE
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /bin/app ./${SERVICE}

FROM gcr.io/distroless/static-debian12@sha256:6447365a6337c3732f412d1b74357b30a633831955b2bc45552b0086be907687
COPY --from=build /bin/app /app
ADD --chmod=0644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-ca-bundle.pem
ENTRYPOINT ["/app"]
