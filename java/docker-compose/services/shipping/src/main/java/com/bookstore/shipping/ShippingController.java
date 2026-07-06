package com.bookstore.shipping;

import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.Set;

/** HTTP routes for shipping. JSON keys use snake_case to match the shared frontend. */
@RestController
public class ShippingController {

    private static final Set<String> WEST_STATES =
        Set.of("CA", "WA", "OR", "NV", "AZ", "CO", "UT", "NM", "ID", "MT", "WY");

    private static final String INSERT_SHIPMENT_SQL =
        "INSERT INTO shipments "
            + "(order_id, warehouse_id, customer_name, shipping_address, city, state, zip, status) "
            + "VALUES (?, ?, ?, ?, ?, ?, ?, 'processing') "
            + "ON CONFLICT (order_id) DO UPDATE SET warehouse_id = EXCLUDED.warehouse_id "
            + "RETURNING shipment_id";
    private static final String SHIPMENT_SQL =
        "SELECT s.shipment_id, s.order_id, s.status, s.shipped_date, "
            + "s.customer_name, s.shipping_address, s.city, s.state, s.zip, "
            + "w.name AS warehouse_name, w.city AS warehouse_city, w.state AS warehouse_state "
            + "FROM shipments s JOIN warehouses w ON w.warehouse_id = s.warehouse_id "
            + "WHERE s.order_id = ?";

    private final JdbcTemplate jdbc;

    public ShippingController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }

    @PostMapping("/api/shipments")
    public ResponseEntity<?> createShipment(@RequestBody Map<String, Object> body) {
        Object orderId = body.get("order_id");
        if (orderId == null) {
            return ResponseEntity.status(400).body(Map.of("error", "order_id is required"));
        }
        int warehouseId = pickWarehouse(String.valueOf(body.getOrDefault("state", "")));
        Integer shipmentId = jdbc.queryForObject(
            SqlCommenter.annotate(INSERT_SHIPMENT_SQL), Integer.class,
            ((Number) orderId).intValue(), warehouseId,
            body.getOrDefault("customer_name", ""), body.getOrDefault("shipping_address", ""),
            body.getOrDefault("city", ""), body.getOrDefault("state", ""),
            body.getOrDefault("zip", ""));
        return ResponseEntity.status(201).body(Map.of(
            "shipment_id", shipmentId, "order_id", orderId, "warehouse_id", warehouseId));
    }

    @GetMapping("/api/shipping/{orderId}")
    public ResponseEntity<?> getShipment(@PathVariable int orderId) {
        List<Map<String, Object>> rows = jdbc.queryForList(SqlCommenter.annotate(SHIPMENT_SQL), orderId);
        if (rows.isEmpty()) {
            return ResponseEntity.status(404).body(Map.of("error", "shipment not found"));
        }
        Map<String, Object> row = rows.get(0);
        row.put("shipped_date", String.valueOf(row.get("shipped_date")));
        return ResponseEntity.ok(row);
    }

    private static int pickWarehouse(String state) {
        return WEST_STATES.contains(state == null ? "" : state.toUpperCase()) ? 1 : 2;
    }
}
