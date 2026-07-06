package com.bookstore.products;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Products service — serves the book catalog from MySQL (books_inventory). */
@SpringBootApplication
public class ProductsApplication {
    public static void main(String[] args) {
        SpringApplication.run(ProductsApplication.class, args);
    }
}
