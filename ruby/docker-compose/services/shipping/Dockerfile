# Build context is ./services so the shared `common/` code and Gemfile are available.
FROM ruby:4.0-slim@sha256:e41d40671d359ccc3431371e0af7c6430bd1b3886b47ac0667443525b7dcec1a
WORKDIR /app

# Native build deps for mysql2 + pg gems.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential default-libmysqlclient-dev libpq-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile ./
RUN bundle install

COPY common ./common
COPY shipping ./shipping

EXPOSE 8003
CMD ["bundle", "exec", "ruby", "shipping/app.rb"]
