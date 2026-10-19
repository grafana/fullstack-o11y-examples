# Build context is ./services so the shared `common/` code and Gemfile are available.
FROM ruby:4.0-slim@sha256:ba6a00593739f9cb66de80ad2e395a93a52a13635867ee32918ba0ec083b1ff6
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
