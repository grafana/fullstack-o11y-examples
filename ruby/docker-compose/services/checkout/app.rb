# Checkout service -- mock payment, writes orders to MySQL, requests fulfillment.
#
# On checkout it computes the cart total, records one order row per cart line in
# MySQL, simulates a payment (always approved), and calls the shipping service to
# create a shipment for each order. The Faraday call propagates trace context, so
# a single checkout produces one distributed trace: checkout -> MySQL and
# shipping -> Postgres.
require_relative "../common/otel"
Common::Otel.configure("checkout-service")

require "sinatra/base"
require "json"
require "faraday"
require_relative "../common/db"

class CheckoutApp < Sinatra::Base
  set :bind, "0.0.0.0"
  set :port, Integer(ENV.fetch("SERVICE_PORT", "8002"))
  set :default_content_type, "application/json"
  # Sinatra 4.x rejects non-matching Host headers by default; allow service-name
  # and nginx-proxied hosts (empty list permits all).
  set :host_authorization, permitted_hosts: []
  use Common::Otel::ServerSpanMiddleware

  SHIPPING_URL = ENV.fetch("SHIPPING_URL", "http://shipping:8003")

  configure { set :db, Common::DB.mysql }

  helpers do
    def record_order(customer_id, book_id, quantity)
      price = settings.db[:books_inventory].where(book_id: book_id).get(:price)
      total = price.to_f * quantity
      order_id = settings.db[:orders].insert(
        customer_id: customer_id, book_id: book_id, quantity: quantity,
        order_total: total, order_status: "paid", order_date: Sequel.function(:NOW)
      )
      [order_id, total]
    end

    def request_shipment(order_id, customer)
      payload = {
        order_id: order_id,
        customer_name: "#{customer[:first_name]} #{customer[:last_name]}",
        shipping_address: customer[:shipping_address],
        city: customer[:city], state: customer[:state], zip: customer[:zip]
      }
      resp = Faraday.post("#{SHIPPING_URL}/api/shipments") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = payload.to_json
      end
      JSON.parse(resp.body)
    end
  end

  get "/health" do
    { status: "ok" }.to_json
  end

  post "/api/checkout" do
    body = JSON.parse(request.body.read, symbolize_names: true) rescue {}
    customer_id = body[:customer_id]
    items = body[:items] || []
    halt 400, { error: "customer_id and items are required" }.to_json if customer_id.nil? || items.empty?

    customer = settings.db[:customers].where(customer_id: customer_id).first
    halt 404, { error: "customer not found" }.to_json if customer.nil?

    orders = []
    grand_total = 0.0
    settings.db.transaction do
      items.each do |item|
        order_id, total = record_order(customer_id, item[:book_id], item[:quantity] || 1)
        grand_total += total
        orders << { order_id: order_id, book_id: item[:book_id], total: total }
      end
    end

    shipments = orders.map { |o| request_shipment(o[:order_id], customer) }
    status 201
    {
      status: "confirmed", payment: "approved",
      orders: orders, shipments: shipments, grand_total: grand_total.round(2)
    }.to_json
  end

  get "/api/orders" do
    cid = params[:customer_id]
    halt 400, { error: "customer_id query parameter is required" }.to_json if cid.nil? || cid.empty?
    rows = settings.db[:orders]
           .join(:books_inventory, book_id: :book_id)
           .where(Sequel[:orders][:customer_id] => Integer(cid))
           .order(Sequel.desc(Sequel[:orders][:order_date]), Sequel.desc(Sequel[:orders][:order_id]))
           .select(
             Sequel[:orders][:order_id], Sequel[:orders][:book_id],
             Sequel[:books_inventory][:title], Sequel[:orders][:quantity],
             Sequel[:orders][:order_total], Sequel[:orders][:order_status],
             Sequel[:orders][:order_date]
           ).all
    rows.map { |r| r.merge(order_total: r[:order_total].to_f, order_date: r[:order_date].to_s) }.to_json
  end

  get "/api/orders/:id" do
    row = settings.db[:orders].where(order_id: Integer(params[:id])).first
    halt 404, { error: "order not found" }.to_json if row.nil?
    row.merge(order_total: row[:order_total].to_f, order_date: row[:order_date].to_s).to_json
  end

  run! if app_file == $PROGRAM_NAME
end
