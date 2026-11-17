ARG ALLOY_IMAGE=grafana/alloy:v1.22.0@sha256:9acc2529bc1edb7f5b2bd801dd8334ebc80c158e3a9e5526ecd7c9a273d43189
FROM ${ALLOY_IMAGE}
# SQL Server client connections verify the Amazon RDS certificate chain.
ADD --chmod=0644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-ca-bundle.pem
