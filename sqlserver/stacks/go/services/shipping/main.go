// Shipping service — chooses a warehouse per order and records it in SQL Server.
//
// Books ship from the West Coast (California) warehouse for western customers and
// from the East Coast (New York) warehouse otherwise.
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"bookstore/common"
)

type ShipmentRequest struct {
	OrderID         int64  `json:"order_id"`
	CustomerName    string `json:"customer_name"`
	ShippingAddress string `json:"shipping_address"`
	City            string `json:"city"`
	State           string `json:"state"`
	Zip             string `json:"zip"`
}

var (
	db         *sql.DB
	westStates = map[string]bool{"CA": true, "WA": true, "OR": true, "NV": true, "AZ": true, "CO": true, "UT": true, "NM": true, "ID": true, "MT": true, "WY": true}
)

func main() {
	ctx := context.Background()
	shutdown, err := common.InitTelemetry(ctx, "shipping-service")
	if err != nil {
		log.Fatalf("telemetry: %v", err)
	}
	defer shutdown(ctx)

	db, err = common.OpenShipping()
	if err != nil {
		log.Fatalf("SQL Server: %v", err)
	}
	defer db.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		common.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("POST /api/shipments", createShipment)
	mux.HandleFunc("GET /api/shipping/{order_id}", getShipment)

	addr := ":" + common.Port("8003")
	log.Printf("shipping-service listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, common.Instrument(mux)))
}

func pickWarehouse(state string) int {
	if westStates[strings.ToUpper(state)] {
		return 1
	}
	return 2
}

func createShipment(w http.ResponseWriter, r *http.Request) {
	var req ShipmentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	warehouseID := pickWarehouse(req.State)
	rows, err := db.QueryContext(r.Context(),
		"MERGE dbo.shipments WITH (HOLDLOCK) AS target "+
			"USING (VALUES (@p1, @p2, @p3, @p4, @p5, @p6, @p7)) "+
			"AS source (order_id, warehouse_id, customer_name, shipping_address, city, state, zip) "+
			"ON target.order_id = source.order_id "+
			"WHEN MATCHED THEN UPDATE SET warehouse_id = source.warehouse_id "+
			"WHEN NOT MATCHED THEN INSERT "+
			"(order_id, warehouse_id, customer_name, shipping_address, city, state, zip, status) "+
			"VALUES (source.order_id, source.warehouse_id, source.customer_name, source.shipping_address, "+
			"source.city, source.state, source.zip, 'processing') "+
			"OUTPUT INSERTED.shipment_id;",
		req.OrderID, warehouseID, req.CustomerName, req.ShippingAddress, req.City, req.State, req.Zip)
	if err != nil {
		common.WriteError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()
	var shipmentID int
	if rows.Next() {
		_ = rows.Scan(&shipmentID)
	}
	common.WriteJSON(w, http.StatusCreated, map[string]any{
		"shipment_id": shipmentID, "order_id": req.OrderID, "warehouse_id": warehouseID,
	})
}

func getShipment(w http.ResponseWriter, r *http.Request) {
	orderID, err := strconv.Atoi(r.PathValue("order_id"))
	if err != nil {
		common.WriteError(w, http.StatusBadRequest, "invalid order_id")
		return
	}
	rows, err := db.QueryContext(r.Context(),
		"SELECT s.shipment_id, s.order_id, s.status, s.shipped_date, "+
			"s.customer_name, s.shipping_address, s.city, s.state, s.zip, "+
			"w.name, w.city, w.state "+
			"FROM shipments s JOIN warehouses w ON w.warehouse_id = s.warehouse_id "+
			"WHERE s.order_id = @p1", orderID)
	if err != nil {
		common.WriteError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()
	if !rows.Next() {
		common.WriteError(w, http.StatusNotFound, "shipment not found")
		return
	}
	common.WriteJSON(w, http.StatusOK, scanShipment(rows))
}

func scanShipment(rows *sql.Rows) map[string]any {
	var (
		shipmentID, orderID                  int
		status, name, addr, city, state, zip string
		whName, whCity, whState              string
		shipped                              sql.NullTime
	)
	if err := rows.Scan(&shipmentID, &orderID, &status, &shipped, &name, &addr,
		&city, &state, &zip, &whName, &whCity, &whState); err != nil {
		return map[string]any{"error": err.Error()}
	}
	shippedDate := any(nil)
	if shipped.Valid {
		shippedDate = shipped.Time.Format(time.DateOnly)
	}
	return map[string]any{
		"shipment_id": shipmentID, "order_id": orderID, "status": status,
		"shipped_date": shippedDate, "customer_name": name, "shipping_address": addr,
		"city": city, "state": state, "zip": zip,
		"warehouse_name": whName, "warehouse_city": whCity, "warehouse_state": whState,
	}
}
