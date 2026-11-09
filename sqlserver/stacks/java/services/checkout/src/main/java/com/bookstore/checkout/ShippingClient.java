package com.bookstore.checkout;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.LinkedHashMap;
import java.util.Map;

/** Calls the shipping service to create a shipment per order. */
@Component
public class ShippingClient {

    private final RestClient restClient;
    private final String shippingUrl;

    public ShippingClient(RestClient restClient,
                          @Value("${SHIPPING_URL:http://shipping:8003}") String shippingUrl) {
        this.restClient = restClient;
        this.shippingUrl = shippingUrl;
    }

    /** POSTs a shipment request; the OTel Java agent propagates trace context. */
    public Object createShipment(Number orderId, Map<String, Object> customer) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("order_id", orderId);
        payload.put("customer_name", customer.get("first_name") + " " + customer.get("last_name"));
        payload.put("shipping_address", customer.get("shipping_address"));
        payload.put("city", customer.get("city"));
        payload.put("state", customer.get("state"));
        payload.put("zip", customer.get("zip"));
        return restClient.post()
            .uri(shippingUrl + "/api/shipments")
            .body(payload)
            .retrieve()
            .body(Object.class);
    }
}
