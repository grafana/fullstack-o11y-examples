# Shipping service -- chooses a warehouse per order and records it in PostgreSQL.
#
# Books ship from the West Coast (California) warehouse for western customers and
# from the East Coast (New York) warehouse otherwise.
require_relative "../common/otel"
Common::Otel.configure("shipping-service")

require "sinatra/base"
require "json"
require_relative "../common/db"

class ShippingApp < Sinatra::Base
  set :bind, "0.0.0.0"
  set :port, Integer(ENV.fetch("SERVICE_PORT", "8003"))
  set :default_content_type, "application/json"
  # Sinatra 4.x rejects non-matching Host headers by default; allow service-name
  # and nginx-proxied hosts (empty list permits all).
  set :host_authorization, permitted_hosts: []
  use Common::Otel::ServerSpanMiddleware

  WEST_STATES = %w[CA WA OR NV AZ CO UT NM ID MT WY].freeze

  configure { set :db, Common::DB.postgres }

  helpers do
    def pick_warehouse(state)
      WEST_STATES.include?((state || "").upcase) ? 1 : 2
    end

    def upsert_shipment(params)
      settings.db[:shipments]
        .insert_conflict(target: :order_id, update: { warehouse_id: Sequel[:excluded][:warehouse_id] })
        .returning(:shipment_id)
        .insert(params)
        .first[:shipment_id]
    end
  end

  get "/health" do
    { status: "ok" }.to_json
  end

  post "/api/shipments" do
    body = JSON.parse(request.body.read, symbolize_names: true) rescue {}
    warehouse_id = pick_warehouse(body[:state])
    params = {
      order_id: body[:order_id], warehouse_id: warehouse_id,
      customer_name: body[:customer_name].to_s,
      shipping_address: body[:shipping_address].to_s,
      city: body[:city].to_s, state: body[:state].to_s,
      zip: body[:zip].to_s, status: "processing"
    }
    shipment_id = upsert_shipment(params)
    status 201
    { shipment_id: shipment_id, order_id: params[:order_id], warehouse_id: warehouse_id }.to_json
  end

  get "/api/shipping/:order_id" do
    row = settings.db[:shipments]
          .join(:warehouses, warehouse_id: :warehouse_id)
          .where(Sequel[:shipments][:order_id] => Integer(params[:order_id]))
          .select(
            Sequel[:shipments][:shipment_id], Sequel[:shipments][:order_id],
            Sequel[:shipments][:status], Sequel[:shipments][:shipped_date],
            Sequel[:shipments][:customer_name], Sequel[:shipments][:shipping_address],
            Sequel[:shipments][:city], Sequel[:shipments][:state], Sequel[:shipments][:zip],
            Sequel[:warehouses][:name].as(:warehouse_name),
            Sequel[:warehouses][:city].as(:warehouse_city),
            Sequel[:warehouses][:state].as(:warehouse_state)
          )
          .first
    halt 404, { error: "shipment not found" }.to_json if row.nil?
    row.merge(shipped_date: row[:shipped_date].to_s).to_json
  end

  run! if app_file == $PROGRAM_NAME
end
