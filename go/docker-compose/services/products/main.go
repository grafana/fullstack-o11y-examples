// Products service — serves the book catalog from MySQL (books_inventory).
package main

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"strconv"

	"bookstore/common"
)

type Book struct {
	BookID        int     `json:"book_id"`
	Title         string  `json:"title"`
	Author        string  `json:"author"`
	ISBN          string  `json:"isbn"`
	Genre         string  `json:"genre"`
	Price         float64 `json:"price"`
	StockQuantity int     `json:"stock_quantity"`
}

const selectCols = "book_id, title, author, isbn, genre, price, stock_quantity"

var db *sql.DB

func main() {
	ctx := context.Background()
	shutdown, err := common.InitTelemetry(ctx, "products-service")
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
	mux.HandleFunc("GET /health", health)
	mux.HandleFunc("GET /api/products", listProducts)
	mux.HandleFunc("GET /api/products/{id}", getProduct)

	addr := ":" + common.Port("8001")
	log.Printf("products-service listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, common.Instrument(mux)))
}

func scanBook(rows *sql.Rows) (Book, error) {
	var b Book
	err := rows.Scan(&b.BookID, &b.Title, &b.Author, &b.ISBN, &b.Genre, &b.Price, &b.StockQuantity)
	return b, err
}

func health(w http.ResponseWriter, _ *http.Request) {
	common.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func listProducts(w http.ResponseWriter, r *http.Request) {
	rows, err := db.QueryContext(r.Context(),
		"SELECT "+selectCols+" FROM books_inventory ORDER BY title")
	if err != nil {
		common.WriteError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	books := []Book{}
	for rows.Next() {
		b, err := scanBook(rows)
		if err != nil {
			common.WriteError(w, http.StatusInternalServerError, err.Error())
			return
		}
		books = append(books, b)
	}
	common.WriteJSON(w, http.StatusOK, books)
}

func getProduct(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		common.WriteError(w, http.StatusBadRequest, "invalid id")
		return
	}
	rows, err := db.QueryContext(r.Context(),
		"SELECT "+selectCols+" FROM books_inventory WHERE book_id = ?", id)
	if err != nil {
		common.WriteError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()
	if !rows.Next() {
		common.WriteError(w, http.StatusNotFound, "book not found")
		return
	}
	b, err := scanBook(rows)
	if err != nil {
		common.WriteError(w, http.StatusInternalServerError, err.Error())
		return
	}
	common.WriteJSON(w, http.StatusOK, b)
}
