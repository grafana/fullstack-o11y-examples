# Products service -- serves the book catalog from MySQL (books_inventory).
require_relative "../common/otel"
Common::Otel.configure("products-service")

require "sinatra/base"
require "json"
require_relative "../common/db"

class ProductsApp < Sinatra::Base
  set :bind, "0.0.0.0"
  set :port, Integer(ENV.fetch("SERVICE_PORT", "8001"))
  set :default_content_type, "application/json"
  # Sinatra 4.x rejects non-matching Host headers by default; allow service-name
  # and nginx-proxied hosts (empty list permits all).
  set :host_authorization, permitted_hosts: []
  use Common::Otel::ServerSpanMiddleware

  configure { set :db, Common::DB.mysql }

  COLUMNS = %i[book_id title author isbn genre price stock_quantity].freeze

  helpers do
    def book_row(row)
      row.merge(price: row[:price].to_f)
    end
  end

  get "/health" do
    { status: "ok" }.to_json
  end

  get "/api/products" do
    rows = settings.db[:books_inventory].select(*COLUMNS).order(:title).all
    rows.map { |r| book_row(r) }.to_json
  end

  get "/api/products/:id" do
    row = settings.db[:books_inventory]
          .select(*COLUMNS)
          .where(book_id: Integer(params[:id]))
          .first
    halt 404, { error: "book not found" }.to_json if row.nil?
    book_row(row).to_json
  end

  run! if app_file == $PROGRAM_NAME
end
