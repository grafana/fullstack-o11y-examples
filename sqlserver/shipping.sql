USE [shipping];
GO
CREATE TABLE dbo.warehouses (
  warehouse_id INT IDENTITY(1,1) PRIMARY KEY,
  name VARCHAR(128) NOT NULL,
  address VARCHAR(255) NOT NULL,
  city VARCHAR(64) NOT NULL,
  state VARCHAR(32) NOT NULL,
  zip VARCHAR(16) NOT NULL
);
CREATE TABLE dbo.shipments (
  shipment_id INT IDENTITY(1,1) PRIMARY KEY,
  order_id INT NOT NULL UNIQUE,
  warehouse_id INT NOT NULL,
  customer_name VARCHAR(128) NOT NULL,
  shipping_address VARCHAR(255) NOT NULL,
  city VARCHAR(64) NOT NULL,
  state VARCHAR(32) NOT NULL,
  zip VARCHAR(16) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  shipped_date DATE NULL,
  CONSTRAINT fk_shipments_warehouse FOREIGN KEY (warehouse_id) REFERENCES dbo.warehouses(warehouse_id)
);
CREATE INDEX idx_shipments_order ON dbo.shipments(order_id);
GO
INSERT INTO dbo.warehouses (name,address,city,state,zip) VALUES
('West Coast Fulfillment Center','1000 Warehouse Way','Oakland','California','94607'),
('East Coast Distribution Hub','2000 Logistics Blvd','Buffalo','New York','14201');
GO

;WITH numbers AS (
  SELECT TOP (100) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS order_id
  FROM sys.all_objects AS a CROSS JOIN sys.all_objects AS b
)
INSERT INTO dbo.shipments
  (order_id,warehouse_id,customer_name,shipping_address,city,state,zip,status,shipped_date)
SELECT n.order_id,
  CASE WHEN c.state IN ('CA','WA','OR','NV','AZ','CO','UT','NM','ID','MT','WY') THEN 1 ELSE 2 END,
  CONCAT(c.first_name,' ',c.last_name),c.shipping_address,c.city,c.state,c.zip,
  CASE n.order_id % 4 WHEN 0 THEN 'pending' WHEN 1 THEN 'processing'
    WHEN 2 THEN 'shipped' ELSE 'delivered' END,
  CASE WHEN n.order_id % 4 IN (2,3) THEN DATEADD(day,-(n.order_id % 30),CONVERT(date,GETDATE())) END
FROM numbers AS n
JOIN [bookstore].dbo.customers AS c ON c.customer_id = ((n.order_id - 1) / 10) + 1;
GO
