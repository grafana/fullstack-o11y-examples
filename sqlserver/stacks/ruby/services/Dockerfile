# Build context is ./services so the shared `common/` code and Gemfile are available.
FROM ruby:4.0-slim@sha256:58479f164d5947f852da27a4436c89bb986a811f959c40552bc7f6ccaabcc9c9
ARG SERVICE
WORKDIR /app

# Native build deps for the TinyTDS SQL Server gem.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential freetds-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile ./
RUN bundle install

COPY common ./common
ENV FREETDSCONF=/app/common/freetds.conf
COPY ${SERVICE} ./${SERVICE}

ADD --chmod=0644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-ca-bundle.pem
ENV APP_ENTRY=${SERVICE}/app.rb
CMD ["sh", "-c", "exec bundle exec ruby \"$APP_ENTRY\""]
