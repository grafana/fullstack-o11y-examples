# Build context is ./services so the shared `common/` code and Gemfile are available.
FROM ruby:3.4-slim@sha256:66ce991f12c58f5038c9f7c34df36d624d10c84500b748a7036c621c43cf154e
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
