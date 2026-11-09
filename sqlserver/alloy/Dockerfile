ARG ALLOY_IMAGE=grafana/alloy:v1.21.3@sha256:8ab871206bd2d8f89277f53abffee5f452a293980788d52f85fa183a87a505a4
FROM ${ALLOY_IMAGE}
# SQL Server client connections verify the Amazon RDS certificate chain.
ADD --chmod=0644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-ca-bundle.pem
