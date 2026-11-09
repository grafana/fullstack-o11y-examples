package com.bookstore.checkout;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.web.client.RestClient;

/**
 * Checkout service — mock payment, writes orders to SQL Server, requests fulfillment.
 *
 * <p>A single checkout records one order row per cart line in SQL Server, simulates a
 * payment (always approved), and calls the shipping service for each order. The
 * OTel Java agent propagates trace context on the outbound call, so one checkout
 * yields a distributed trace across checkout -> SQL Server and shipping -> SQL Server.
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
