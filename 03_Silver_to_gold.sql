-- Databricks notebook source
CREATE SCHEMA IF NOT EXISTS customer360_gold;

CREATE  TABLE customer360_gold.dim_customer AS

SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,

    customer_id,
    first_name,
    last_name,
    email,
    phone_number,
    gender,
    dob,
    signup_date,
    city,
    state,
    country,
    source

FROM customer360_silver.customers;

-- COMMAND ----------

SELECT *
FROM customer360_gold.dim_customer
LIMIT 10;

-- COMMAND ----------

SELECT phone_number
FROM customer360_silver.customers
LIMIT 10;

-- COMMAND ----------

UPDATE customer360_silver.customers
SET phone_number = REGEXP_REPLACE(
                      REGEXP_REPLACE(phone_number, 'x.*$', ''),
                      '[^0-9]',
                      ''
                  );

-- COMMAND ----------

SELECT phone_number
FROM customer360_silver.customers
LIMIT 20;

-- COMMAND ----------

SELECT
LENGTH(phone_number) AS phone_length,
COUNT(*) AS cnt
FROM customer360_silver.customers
GROUP BY LENGTH(phone_number)
ORDER BY phone_length;

-- COMMAND ----------

SELECT phone_number
FROM customer360_silver.customers
WHERE LENGTH(phone_number) = 13
LIMIT 20;

-- COMMAND ----------

SELECT
    LENGTH(phone_number) AS phone_length,
    COUNT(*) AS cnt
FROM customer360_silver.customers
GROUP BY LENGTH(phone_number)
ORDER BY phone_length;

-- COMMAND ----------

SELECT
customer_id,
phone_number
FROM customer360_silver.customers
WHERE LENGTH(phone_number)=7;

-- COMMAND ----------

DESCRIBE HISTORY customer360_silver.customers;

-- COMMAND ----------

RESTORE TABLE customer360_silver.customers
TO VERSION AS OF 0;

-- COMMAND ----------

SELECT COUNT(*)
FROM customer360_silver.customers;

-- COMMAND ----------

DESCRIBE HISTORY customer360_silver.customers;

-- COMMAND ----------

RESTORE TABLE customer360_silver.customers
TO VERSION AS OF 1;

-- COMMAND ----------

SELECT
    LENGTH(phone_number) AS phone_length,
    COUNT(*) AS cnt
FROM customer360_silver.customers
GROUP BY LENGTH(phone_number)
ORDER BY phone_length;

-- COMMAND ----------

UPDATE customer360_silver.customers
SET phone_number =
CASE
    WHEN LENGTH(phone_number) = 13
         AND phone_number LIKE '001%'
    THEN SUBSTRING(phone_number, 4)

    WHEN LENGTH(phone_number) = 11
         AND phone_number LIKE '1%'
    THEN SUBSTRING(phone_number, 2)

    ELSE phone_number
END;

-- COMMAND ----------

SELECT
    LENGTH(phone_number) AS phone_length,
    COUNT(*) AS cnt
FROM customer360_silver.customers
GROUP BY LENGTH(phone_number)
ORDER BY phone_length;

-- COMMAND ----------

SHOW TABLES IN customer360_gold;

-- COMMAND ----------

REPLACE TABLE customer360_gold.dim_customer AS

SELECT

    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,

    customer_id,first_name,last_name,email,phone_number,gender,dob,signup_date,city,state,country,source

FROM customer360_silver.customers;

-- COMMAND ----------

SELECT COUNT(*)
FROM customer360_gold.dim_customer;

-- COMMAND ----------

SELECT

MIN(customer_key),

MAX(customer_key),

COUNT(DISTINCT customer_key)

FROM customer360_gold.dim_customer;

-- COMMAND ----------

DESCRIBE customer360_silver.products


-- COMMAND ----------

CREATE or REPLACE TABLE customer360_gold.dim_product AS

SELECT

    ROW_NUMBER() OVER (ORDER BY product_id) AS product_key,

    product_id,

    product_name,

    category,

    price

FROM customer360_silver.products;

-- COMMAND ----------

SELECT COUNT(*) AS total_rows
FROM customer360_gold.dim_product;

-- COMMAND ----------

SELECT
    MIN(product_key) AS min_key,
    MAX(product_key) AS max_key,
    COUNT(DISTINCT product_key) AS distinct_keys
FROM customer360_gold.dim_product;

-- COMMAND ----------

SELECT
    product_id,
    COUNT(*) AS cnt
FROM customer360_gold.dim_product
GROUP BY product_id
HAVING COUNT(*) > 1;

-- COMMAND ----------

SELECT
    MIN(min_date) AS start_date,
    MAX(max_date) AS end_date
FROM
(
    SELECT MIN(signup_date) AS min_date,
           MAX(signup_date) AS max_date
    FROM customer360_silver.customers

    UNION ALL

    SELECT MIN(order_date),
           MAX(order_date)
    FROM customer360_silver.orders

    UNION ALL

    SELECT MIN(ticket_created),
           MAX(ticket_created)
    FROM customer360_silver.support_tickets

    UNION ALL

    SELECT MIN(ticket_resolved),
           MAX(ticket_resolved)
    FROM customer360_silver.support_tickets

    UNION ALL

    SELECT MIN(CAST(timestamp AS DATE)),
           MAX(CAST(timestamp AS DATE))
    FROM customer360_silver.clickstream
) t;

-- COMMAND ----------

CREATE or REPLACE TABLE customer360_gold.dim_date AS

SELECT
    CAST(DATE_FORMAT(d, 'yyyyMMdd') AS INT) AS date_key,
    d AS full_date,
    YEAR(d) AS year,
    QUARTER(d) AS quarter,
    MONTH(d) AS month,
    DATE_FORMAT(d, 'MMMM') AS month_name,
    DAY(d) AS day,
    DATE_FORMAT(d, 'EEEE') AS day_name,
    WEEKOFYEAR(d) AS week_of_year,

    CASE
        WHEN DAYOFWEEK(d) IN (1,7) THEN 'Yes'
        ELSE 'No'
    END AS is_weekend

FROM (
    SELECT EXPLODE(
        SEQUENCE(
            TO_DATE('2013-01-01'),
            TO_DATE('2027-12-31'),
            INTERVAL 1 DAY
        )
    ) AS d
);

-- COMMAND ----------

SELECT COUNT(*)
FROM customer360_gold.dim_date;

-- COMMAND ----------

SELECT *
FROM customer360_gold.dim_date
LIMIT 10;

-- COMMAND ----------


CREATE TABLE customer360_gold.fact_orders AS

SELECT

    o.order_id,

    dc.customer_key,

    dp.product_key,

    dd.date_key,

    o.quantity,

    o.order_amount,

    o.payment_method

FROM customer360_silver.orders o

LEFT JOIN customer360_gold.dim_customer dc
    ON o.customer_id = dc.customer_id

LEFT JOIN customer360_gold.dim_product dp
    ON o.product_id = dp.product_id

LEFT JOIN customer360_gold.dim_date dd
    ON o.order_date = dd.full_date;

-- COMMAND ----------

describe customer360_gold.fact_orders


-- COMMAND ----------

select distinct issue_type from customer360_silver.support_tickets

-- COMMAND ----------

CREATE or REPLACE TABLE customer360_gold.dim_support_agent AS

SELECT

    ROW_NUMBER() OVER (ORDER BY support_agent) AS support_agent_key,

    support_agent

FROM (

    SELECT DISTINCT support_agent

    FROM customer360_silver.support_tickets

    WHERE support_agent IS NOT NULL

);

-- COMMAND ----------

CREATE or REPLACE TABLE customer360_gold.fact_support_tickets AS

SELECT

    st.ticket_id,

    dc.customer_key,

    d1.date_key AS created_date_key,

    d2.date_key AS resolved_date_key,

    sa.support_agent_key,

    st.issue_type,

    st.sentiment,

    st.resolution_time_hours

FROM customer360_silver.support_tickets st

LEFT JOIN customer360_gold.dim_customer dc
    ON st.customer_id = dc.customer_id

LEFT JOIN customer360_gold.dim_date d1
    ON st.ticket_created = d1.full_date

LEFT JOIN customer360_gold.dim_date d2
    ON st.ticket_resolved = d2.full_date

LEFT JOIN customer360_gold.dim_support_agent sa
    ON st.support_agent = sa.support_agent;

-- COMMAND ----------

create TABLE customer360_gold.fact_clickstream AS

SELECT

    c.event_id,

    dc.customer_key,

    dd.date_key,

    c.event_type

FROM customer360_silver.clickstream c

LEFT JOIN customer360_gold.dim_customer dc
    ON c.customer_id = dc.customer_id

LEFT JOIN customer360_gold.dim_date dd
    ON CAST(c.timestamp AS DATE) = dd.full_date;

-- COMMAND ----------

SELECT *
FROM customer360_gold.dim_customer;

-- COMMAND ----------

SELECT * FROM customer360_gold.dim_product;

-- COMMAND ----------

SELECT * FROM customer360_gold.dim_date;

-- COMMAND ----------

SELECT * FROM customer360_gold.dim_support_agent;

-- COMMAND ----------

SELECT * FROM customer360_gold.fact_orders;

-- COMMAND ----------

SELECT * FROM customer360_gold.fact_support_tickets;

-- COMMAND ----------

SELECT * FROM customer360_gold.fact_clickstream;

-- COMMAND ----------

SELECT
    COUNT(*) AS total_rows,
    COUNT(timestamp) AS non_null_timestamp,
    COUNT(*) - COUNT(timestamp) AS null_timestamp
FROM customer360_silver.clickstream;

-- COMMAND ----------

SELECT timestamp
FROM default.clickstream
LIMIT 10;

-- COMMAND ----------

CREATE OR REPLACE TABLE customer360_silver.clickstream AS

SELECT

    event_id,

    session_id,

    customer_id,

    INITCAP(LOWER(TRIM(event_type))) AS event_type,

    TRIM(page_url) AS page_url,

    TRIM(device_id) AS device_id,

    TRY_CAST(timestamp AS TIMESTAMP) AS timestamp,

    ingest_run_id

FROM default.clickstream;

-- COMMAND ----------

SELECT
COUNT(*) total,
COUNT(timestamp) valid_timestamp
FROM customer360_silver.clickstream;

-- COMMAND ----------

CREATE OR REPLACE TABLE customer360_gold.fact_clickstream AS

SELECT
    c.event_id,
    dc.customer_key,
    dd.date_key,
    c.event_type
FROM customer360_silver.clickstream c

LEFT JOIN customer360_gold.dim_customer dc
    ON c.customer_id = dc.customer_id

LEFT JOIN customer360_gold.dim_date dd
    ON CAST(c.timestamp AS DATE) = dd.full_date;

-- COMMAND ----------

SELECT
   *
FROM customer360_gold.fact_clickstream;

-- COMMAND ----------

SELECT
COUNT(*) total,
COUNT(created_date_key) created_key,
COUNT(resolved_date_key) resolved_key
FROM customer360_gold.fact_support_tickets;

-- COMMAND ----------

SELECT
COUNT(*) total,
COUNT(ticket_created) created_not_null,
COUNT(ticket_resolved) resolved_not_null
FROM customer360_silver.support_tickets;

-- COMMAND ----------

SELECT
    ticket_created,
    CAST(ticket_created AS DATE) AS created_date
FROM customer360_silver.support_tickets
LIMIT 10;

-- COMMAND ----------

SELECT *
FROM customer360_gold.dim_date
LIMIT 10;

-- COMMAND ----------

CREATE OR REPLACE TABLE customer360_gold.fact_support_tickets AS

SELECT

    s.ticket_id,

    dc.customer_key,

    d_created.date_key AS created_date_key,

    d_resolved.date_key AS resolved_date_key,

    da.support_agent_key,

    s.issue_type,

    s.sentiment,

    s.resolution_time_hours

FROM customer360_silver.support_tickets s

LEFT JOIN customer360_gold.dim_customer dc
    ON s.customer_id = dc.customer_id

LEFT JOIN customer360_gold.dim_support_agent da
    ON s.support_agent = da.support_agent

LEFT JOIN customer360_gold.dim_date d_created
    ON CAST(s.ticket_created AS DATE) = d_created.full_date

LEFT JOIN customer360_gold.dim_date d_resolved
    ON CAST(s.ticket_resolved AS DATE) = d_resolved.full_date;

-- COMMAND ----------

SELECT
    *
FROM customer360_gold.fact_support_tickets;