// Checkout service — mock payment, writes orders to MySQL, requests fulfillment.
//
// A checkout computes the cart total, records one order row per cart line, fakes
// a payment, and calls the shipping service for each order. The outbound call
// propagates trace context, so one checkout yields a distributed trace spanning
// checkout -> MySQL and shipping -> Postgres.
package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"bookstore/common"
)

type Item struct {
	BookID   int `json:"book_id"`
	Quantity int `json:"quantity"`
}

type CheckoutRequest struct {
	CustomerID int    `json:"customer_id"`
	Items      []Item `json:"items"`
}

type Customer struct {
	ID              int
	FirstName       string
	LastName        string
	ShippingAddress string
	City            string
	State           string
	Zip             string
}

var (
	db          *sql.DB
	shippingURL = common.EnvOr("SHIPPING_URL", "http://shipping:8003")
	httpClient  = common.HTTPClient()
)

func main() {
	ctx := context.Background()
	shutdown, err := common.InitTelemetry(ctx, "checkout-service")
	if err != nil {
		log.Fatalf("telemetry: %v", err)
	}
	defer shutdown(ctx)

	db, err = common.OpenMySQL()
	if err != nil {
		log.Fatalf("mysql: %v", err)
	}
	defer db.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		common.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("POST /api/checkout", checkout)
	mux.HandleFunc("GET /api/orders", listOrders)
	mux.HandleFunc("GET /api/orders/{id}", getOrder)

	addr := ":" + common.Port("8002")
	log.Printf("checkout-service listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, common.Instrument(mux)))
}

func fetchCustomer(ctx context.Context, id int) (Customer, error) {
	rows, err := db.QueryContext(ctx,
		"SELECT customer_id, first_name, last_name, shipping_address, city, state, zip "+
			"FROM customers WHERE customer_id = ?", id)
	if err != nil {
		return Customer{}, err
	}
	defer rows.Close()
	if !rows.Next() {
		return Customer{}, fmt.Errorf("customer not found")
	}
	var c Customer
	err = rows.Scan(&c.ID, &c.FirstName, &c.LastName, &c.ShippingAddress, &c.City, &c.State, &c.Zip)
	return c, err
}

func recordOrder(ctx context.Context, customerID int, item Item) (int64, float64, error) {
	rows, err := db.QueryContext(ctx, "SELECT price FROM books_inventory WHERE book_id = ?", item.BookID)
	if err != nil {
		return 0, 0, err
	}
	defer rows.Close()
	if !rows.Next() {
		return 0, 0, fmt.Errorf("book %d not found", item.BookID)
	}
	var price float64
	if err := rows.Scan(&price); err != nil {
		return 0, 0, err
	}
	total := price * float64(item.Quantity)
	res, err := db.ExecContext(ctx,
		"INSERT INTO orders (customer_id, book_id, quantity, order_total, order_status, order_date) "+
			"VALUES (?, ?, ?, ?, 'paid', NOW())", customerID, item.BookID, item.Quantity, total)
	if err != nil {
		return 0, 0, err
	}
	id, err := res.LastInsertId()
	return id, total, err
}

func requestShipment(ctx context.Context, orderID int64, c Customer) (map[string]any, error) {
	payload := map[string]any{
		"order_id": orderID, "customer_name": c.FirstName + " " + c.LastName,
		"shipping_address": c.ShippingAddress, "city": c.City, "state": c.State, "zip": c.Zip,
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		shippingURL+"/api/shipments", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var out map[string]any
	err = json.NewDecoder(resp.Body).Decode(&out)
	return out, err
}

func checkout(w http.ResponseWriter, r *http.Request) {
	var req CheckoutRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.CustomerID == 0 || len(req.Items) == 0 {
		common.WriteError(w, http.StatusBadRequest, "customer_id and items are required")
		return
	}
	ctx := r.Context()
	customer, err := fetchCustomer(ctx, req.CustomerID)
	if err != nil {
		common.WriteError(w, http.StatusNotFound, err.Error())
		return
	}

	orders := []map[string]any{}
	shipments := []map[string]any{}
	grandTotal := 0.0
	for _, item := range req.Items {
		orderID, total, err := recordOrder(ctx, req.CustomerID, item)
		if err != nil {
			common.WriteError(w, http.StatusInternalServerError, err.Error())
			return
		}
		grandTotal += total
		orders = append(orders, map[string]any{"order_id": orderID, "book_id": item.BookID, "total": total})
		shipment, err := requestShipment(ctx, orderID, customer) // mock payment: always approved
		if err != nil {
			common.WriteError(w, http.StatusBadGateway, "shipping: "+err.Error())
			return
		}
		shipments = append(shipments, shipment)
	}
	common.WriteJSON(w, http.StatusCreated, map[string]any{
		"status": "confirmed", "payment": "approved",
		"orders": orders, "shipments": shipments, "grand_total": grandTotal,
	})
}

func listOrders(w http.ResponseWriter, r *http.Request) {
	customerID, err := strconv.Atoi(r.URL.Query().Get("customer_id"))
	if err != nil {
		common.WriteError(w, http.StatusBadRequest, "customer_id query parameter is required")
		return
	}
	rows, err := db.QueryContext(r.Context(),
		"SELECT o.order_id, o.book_id, b.title, o.quantity, o.order_total, o.order_status, o.order_date "+
			"FROM orders o JOIN books_inventory b ON b.book_id = o.book_id "+
			"WHERE o.customer_id = ? ORDER BY o.order_date DESC, o.order_id DESC", customerID)
	if err != nil {
		common.WriteError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()
	orders := []map[string]any{}
	for rows.Next() {
		var (
			orderID, bookID, quantity int
			title, status            string
			total                    float64
			orderDate                time.Time
		)
		if err := rows.Scan(&orderID, &bookID, &title, &quantity, &total, &status, &orderDate); err != nil {
			common.WriteError(w, http.StatusInternalServerError, err.Error())
			return
		}
		orders = append(orders, map[string]any{
			"order_id": orderID, "book_id": bookID, "title": title, "quantity": quantity,
			"order_total": total, "order_status": status, "order_date": orderDate.Format(time.RFC3339),
		})
	}
	common.WriteJSON(w, http.StatusOK, orders)
}

func getOrder(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		common.WriteError(w, http.StatusBadRequest, "invalid id")
		return
	}
	rows, err := db.QueryContext(r.Context(),
		"SELECT order_id, customer_id, book_id, quantity, order_total, order_status, order_date "+
			"FROM orders WHERE order_id = ?", id)
	if err != nil {
		common.WriteError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()
	if !rows.Next() {
		common.WriteError(w, http.StatusNotFound, "order not found")
		return
	}
	var (
		orderID, customerID, bookID, quantity int
		total                                 float64
		status                                string
		orderDate                             time.Time
	)
	if err := rows.Scan(&orderID, &customerID, &bookID, &quantity, &total, &status, &orderDate); err != nil {
		common.WriteError(w, http.StatusInternalServerError, err.Error())
		return
	}
	common.WriteJSON(w, http.StatusOK, map[string]any{
		"order_id": orderID, "customer_id": customerID, "book_id": bookID,
		"quantity": quantity, "order_total": total, "order_status": status,
		"order_date": orderDate.Format(time.RFC3339),
	})
}
