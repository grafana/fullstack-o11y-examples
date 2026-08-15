# Build context is ./services so the shared `common/` code and Gemfile are available.
FROM ruby:3.3-slim@sha256:649a5d3b7ca4f574a5f84a61bd79cdc7cca2bbd1f882fbe6c1eb4fdbc7454738
WORKDIR /app

# Native build deps for mysql2 + pg gems.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential default-libmysqlclient-dev libpq-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile ./
RUN bundle install

COPY common ./common
COPY checkout ./checkout

EXPOSE 8002
CMD ["bundle", "exec", "ruby", "checkout/app.rb"]
