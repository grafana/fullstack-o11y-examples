# Shared database connection helpers (Sequel) with SQLCommenter enabled.
require "sequel"
require_relative "sqlcommenter"

module Common
  module DB
    # Connect to the bookstore MySQL database (products + checkout).
    def self.mysql
      db = Sequel.connect(
        adapter: "mysql2",
        host: ENV.fetch("MYSQL_HOST"),
        port: Integer(ENV.fetch("MYSQL_PORT", "3306")),
        database: ENV.fetch("MYSQL_DATABASE"),
        user: ENV.fetch("MYSQL_USER"),
        password: ENV.fetch("MYSQL_PASSWORD"),
        max_connections: 5
      )
      db.extension(:sqlcommenter)
      db
    end

    # Connect to the shipping PostgreSQL database.
    def self.postgres
      db = Sequel.connect(
        adapter: "postgres",
        host: ENV.fetch("POSTGRES_HOST"),
        port: Integer(ENV.fetch("POSTGRES_PORT", "5432")),
        database: ENV.fetch("POSTGRES_DB"),
        user: ENV.fetch("POSTGRES_USER"),
        password: ENV.fetch("POSTGRES_PASSWORD"),
        max_connections: 5
      )
      db.extension(:sqlcommenter)
      db
    end
  end
end
