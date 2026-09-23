# Build context is ./services so the shared `common/` code and Gemfile are available.
FROM ruby:4.0-slim@sha256:815184398ba6e53baf80faf8b9338789b6c66823e2324fa9cf73cd0332195cd1
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
