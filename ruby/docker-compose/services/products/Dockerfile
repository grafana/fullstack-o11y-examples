# Build context is ./services so the shared `common/` code and Gemfile are available.
FROM ruby:4.0-slim@sha256:607bf92fa7ecebb4a0c6654b62cb44c48d94b36b6f5a754611ddbbe3dc5b6135
WORKDIR /app

# Native build deps for mysql2 + pg gems.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential default-libmysqlclient-dev libpq-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile ./
RUN bundle install

COPY common ./common
COPY products ./products

EXPOSE 8001
CMD ["bundle", "exec", "ruby", "products/app.rb"]
