package com.bookstore.shipping;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Shipping service — chooses a warehouse per order and records it in PostgreSQL.
 *
 * <p>Books ship from the West Coast (California) warehouse for western customers
 * and from the East Coast (New York) warehouse otherwise.
 */
@SpringBootApplication
public class ShippingApplication {
    public static void main(String[] args) {
        SpringApplication.run(ShippingApplication.class, args);
    }
}
