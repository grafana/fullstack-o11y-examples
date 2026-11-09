package com.bookstore.products;

import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/** HTTP routes for the product catalog. JSON keys use snake_case (book_id, ...). */
@RestController
public class ProductsController {

    private static final String CATALOG_SQL =
        "SELECT book_id, title, author, isbn, genre, price, stock_quantity "
            + "FROM books_inventory ORDER BY title";
    private static final String BOOK_SQL =
        "SELECT book_id, title, author, isbn, genre, price, stock_quantity "
            + "FROM books_inventory WHERE book_id = ?";

    private final JdbcTemplate jdbc;

    public ProductsController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }

    @GetMapping("/api/products")
    public List<Map<String, Object>> listProducts() {
        return jdbc.query(SqlCommenter.annotate(CATALOG_SQL), ProductsController::mapBook);
    }

    @GetMapping("/api/products/{bookId}")
    public ResponseEntity<?> getProduct(@PathVariable int bookId) {
        List<Map<String, Object>> rows =
            jdbc.query(SqlCommenter.annotate(BOOK_SQL), ProductsController::mapBook, bookId);
        if (rows.isEmpty()) {
            return ResponseEntity.status(404).body(Map.of("error", "book not found"));
        }
        return ResponseEntity.ok(rows.get(0));
    }

    private static Map<String, Object> mapBook(java.sql.ResultSet rs, int rowNum) throws java.sql.SQLException {
        Map<String, Object> book = new java.util.LinkedHashMap<>();
        book.put("book_id", rs.getInt("book_id"));
        book.put("title", rs.getString("title"));
        book.put("author", rs.getString("author"));
        book.put("isbn", rs.getString("isbn"));
        book.put("genre", rs.getString("genre"));
        book.put("price", rs.getBigDecimal("price").doubleValue());
        book.put("stock_quantity", rs.getInt("stock_quantity"));
        return book;
    }
}
