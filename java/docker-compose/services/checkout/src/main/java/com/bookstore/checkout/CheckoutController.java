package com.bookstore.checkout;

import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** HTTP routes for checkout. JSON keys use snake_case to match the shared frontend. */
@RestController
public class CheckoutController {

    private static final String CUSTOMER_SQL =
        "SELECT customer_id, first_name, last_name, shipping_address, city, state, zip "
            + "FROM customers WHERE customer_id = ?";
    private static final String PRICE_SQL =
        "SELECT price FROM books_inventory WHERE book_id = ?";
    private static final String INSERT_ORDER_SQL =
        "INSERT INTO orders (customer_id, book_id, quantity, order_total, order_status, order_date) "
            + "VALUES (?, ?, ?, ?, 'paid', NOW())";
    private static final String ORDER_SQL =
        "SELECT order_id, customer_id, book_id, quantity, order_total, order_status, order_date "
            + "FROM orders WHERE order_id = ?";
    private static final String ORDERS_BY_CUSTOMER_SQL =
        "SELECT o.order_id, o.book_id, b.title, o.quantity, o.order_total, o.order_status, o.order_date "
            + "FROM orders o JOIN books_inventory b ON b.book_id = o.book_id "
            + "WHERE o.customer_id = ? ORDER BY o.order_date DESC, o.order_id DESC";

    private final JdbcTemplate jdbc;
    private final ShippingClient shipping;

    public CheckoutController(JdbcTemplate jdbc, ShippingClient shipping) {
        this.jdbc = jdbc;
        this.shipping = shipping;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }

    @PostMapping("/api/checkout")
    public ResponseEntity<?> checkout(@RequestBody Map<String, Object> body) {
        Object customerId = body.get("customer_id");
        List<?> items = (List<?>) body.getOrDefault("items", List.of());
        if (customerId == null || items.isEmpty()) {
            return ResponseEntity.status(400).body(Map.of("error", "customer_id and items are required"));
        }
        Map<String, Object> customer = findCustomer(((Number) customerId).intValue());
        if (customer == null) {
            return ResponseEntity.status(404).body(Map.of("error", "customer not found"));
        }
        return ResponseEntity.status(201).body(process(((Number) customerId).intValue(), items, customer));
    }

    private Map<String, Object> process(int customerId, List<?> items, Map<String, Object> customer) {
        List<Map<String, Object>> orders = new ArrayList<>();
        double grandTotal = 0.0;
        for (Object raw : items) {
            Map<?, ?> item = (Map<?, ?>) raw;
            int bookId = ((Number) item.get("book_id")).intValue();
            int quantity = item.get("quantity") == null ? 1 : ((Number) item.get("quantity")).intValue();
            double total = recordOrder(customerId, bookId, quantity, orders);
            grandTotal += total;
        }
        List<Object> shipments = new ArrayList<>();
        for (Map<String, Object> order : orders) {
            shipments.add(shipping.createShipment((Number) order.get("order_id"), customer));
        }
        return Map.of("status", "confirmed", "payment", "approved", "orders", orders,
            "shipments", shipments, "grand_total", Math.round(grandTotal * 100.0) / 100.0);
    }

    private double recordOrder(int customerId, int bookId, int quantity, List<Map<String, Object>> orders) {
        BigDecimal price = jdbc.queryForObject(SqlCommenter.annotate(PRICE_SQL), BigDecimal.class, bookId);
        double total = price.doubleValue() * quantity;
        long orderId = insertOrder(customerId, bookId, quantity, total);
        orders.add(Map.of("order_id", orderId, "book_id", bookId, "total", total));
        return total;
    }

    private long insertOrder(int customerId, int bookId, int quantity, double total) {
        KeyHolder keys = new GeneratedKeyHolder();
        String sql = SqlCommenter.annotate(INSERT_ORDER_SQL);
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setInt(1, customerId);
            ps.setInt(2, bookId);
            ps.setInt(3, quantity);
            ps.setDouble(4, total);
            return ps;
        }, keys);
        return keys.getKey().longValue();
    }

    private Map<String, Object> findCustomer(int customerId) {
        List<Map<String, Object>> rows = jdbc.queryForList(SqlCommenter.annotate(CUSTOMER_SQL), customerId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    @GetMapping("/api/orders")
    public List<Map<String, Object>> listOrders(@RequestParam("customer_id") int customerId) {
        List<Map<String, Object>> rows = jdbc.queryForList(SqlCommenter.annotate(ORDERS_BY_CUSTOMER_SQL), customerId);
        for (Map<String, Object> row : rows) {
            row.put("order_total", ((Number) row.get("order_total")).doubleValue());
            row.put("order_date", String.valueOf(row.get("order_date")));
        }
        return rows;
    }

    @GetMapping("/api/orders/{orderId}")
    public ResponseEntity<?> getOrder(@PathVariable int orderId) {
        List<Map<String, Object>> rows = jdbc.queryForList(SqlCommenter.annotate(ORDER_SQL), orderId);
        if (rows.isEmpty()) {
            return ResponseEntity.status(404).body(Map.of("error", "order not found"));
        }
        Map<String, Object> row = rows.get(0);
        row.put("order_total", ((Number) row.get("order_total")).doubleValue());
        row.put("order_date", String.valueOf(row.get("order_date")));
        return ResponseEntity.ok(row);
    }
}
