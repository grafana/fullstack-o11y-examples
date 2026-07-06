package com.bookstore.checkout;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.web.client.RestClient;

/**
 * Checkout service — mock payment, writes orders to MySQL, requests fulfillment.
 *
 * <p>A single checkout records one order row per cart line in MySQL, simulates a
 * payment (always approved), and calls the shipping service for each order. The
 * OTel Java agent propagates trace context on the outbound call, so one checkout
 * yields a distributed trace across checkout -> MySQL and shipping -> Postgres.
 */
@SpringBootApplication
public class CheckoutApplication {
    public static void main(String[] args) {
        SpringApplication.run(CheckoutApplication.class, args);
    }

    @Bean
    RestClient restClient() {
        return RestClient.create();
    }
}
