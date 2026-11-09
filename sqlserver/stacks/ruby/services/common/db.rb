# Shared SQL Server connection helper (Sequel) with SQLCommenter enabled.
require "sequel"
require_relative "sqlcommenter"

module Common
  module DB
    def self.sqlserver(database_env)
      db = Sequel.connect(
        adapter: "tinytds",
        host: ENV.fetch("MSSQL_HOST"),
        port: Integer(ENV.fetch("MSSQL_PORT", "1433")),
        database: ENV.fetch(database_env),
        user: ENV.fetch("MSSQL_USER"),
        password: ENV.fetch("MSSQL_PASSWORD"),
        tds_version: "7.4",
        max_connections: 5
      )
      db.extension(:sqlcommenter)
      db
    end
  end
end
