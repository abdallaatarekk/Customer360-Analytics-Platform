-- Databricks notebook source
-- =====================================================
-- Customer360 Project
-- Bronze → Silver Layer
-- Data Cleaning & Standardization
-- =====================================================

-- COMMAND ----------

CREATE SCHEMA IF NOT EXISTS customer360_silver;

-- COMMAND ----------

SHOW SCHEMAS;

-- COMMAND ----------

USE customer360_silver;

-- COMMAND ----------

-- MAGIC %py display(dbutils.fs.ls("/Volumes/workspace/default/customer360_raw/"))

-- COMMAND ----------

-- MAGIC %py import re
-- MAGIC
-- MAGIC files = {
-- MAGIC     "tickets": "support_tickets_30000_dirty.csv",
-- MAGIC     "clickstream": "clickstream_500k_events.csv"
-- MAGIC }
-- MAGIC
-- MAGIC base_path = "/Volumes/workspace/default/customer360_raw/"
-- MAGIC
-- MAGIC for table_name, file_name in files.items():
-- MAGIC
-- MAGIC     print(f"\nLoading {table_name}...")
-- MAGIC
-- MAGIC     df = (
-- MAGIC         spark.read.format("csv")
-- MAGIC         .option("header", "true")
-- MAGIC         .option("inferSchema", "true")
-- MAGIC         .load(base_path + file_name)
-- MAGIC     )
-- MAGIC
-- MAGIC     clean_columns = []
-- MAGIC     for col in df.columns:
-- MAGIC         new_col = re.sub(r'[^A-Za-z0-9_]', '_', col)
-- MAGIC         new_col = re.sub(r'_+', '_', new_col)
-- MAGIC         new_col = new_col.strip("_")
-- MAGIC         clean_columns.append(new_col)
-- MAGIC
-- MAGIC     df = df.toDF(*clean_columns)
-- MAGIC
-- MAGIC     (
-- MAGIC         df.write
-- MAGIC         .mode("overwrite")
-- MAGIC         .saveAsTable(f"default.{table_name}")
-- MAGIC     )
-- MAGIC
-- MAGIC     print(f"✅ {table_name} saved successfully.")

-- COMMAND ----------

SHOW TABLES IN default;

-- COMMAND ----------

USE customer360_silver;

-- COMMAND ----------

SELECT c.*
FROM default.customers c
JOIN (
    SELECT customer_id
    FROM default.customers
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) d
ON c.customer_id = d.customer_id
ORDER BY c.customer_id;


-- COMMAND ----------


SELECT customer_id,dob,
       signup_date
FROM default.customers
WHERE dob >signup_date

-- COMMAND ----------

DESCRIBE default.customers;

-- COMMAND ----------

select distinct source from default.customers

-- COMMAND ----------

CREATE OR REPLACE TABLE customer360_silver.customers AS

WITH cleaned AS (

    SELECT
        customer_id,

        INITCAP(TRIM(REGEXP_REPLACE(first_name, '[0-9]', ''))) AS first_name,

        INITCAP(TRIM(REGEXP_REPLACE(last_name, '[0-9]', ''))) AS last_name,

        email,

        TRIM(phone_number) AS phone_number,

        gender,

        dob,

        signup_date,

        address,

        city,

        state,

        country,

        device_id_s,

        source

    FROM default.customers
),

deduplicated AS (

    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY customer_id
           ) AS rn
    FROM cleaned

)

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    phone_number,
    gender,
    dob,
    signup_date,
    address,
    city,
    state,
    country,
    device_id_s,
    source

FROM deduplicated

WHERE rn = 1;

-- COMMAND ----------

SHOW TABLES IN customer360_silver;

-- COMMAND ----------

SELECT *
FROM customer360_silver.customers


-- COMMAND ----------

SELECT *
FROM customer360_silver.customers
WHERE first_name RLIKE '[0-9]'
   OR last_name RLIKE '[0-9]';

-- COMMAND ----------

SELECT 
      *
FROM customer360_silver.customers
ORDER BY first_name


-- COMMAND ----------

SELECT COUNT(*)
FROM default.customers;

-- COMMAND ----------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM default.customers;

-- COMMAND ----------

SELECT *

FROM default.orders


-- COMMAND ----------

SELECT
    COUNT(*) AS total_rows,

    SUM(
        CASE
            WHEN TRY_CAST(quantity AS INT) IS NULL THEN 1
            ELSE 0
        END
    ) AS non_numeric_rows,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN TRY_CAST(quantity AS INT) IS NULL THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS percentage
FROM default.orders;

-- COMMAND ----------

SELECT
    quantity,
    COUNT(*) AS cnt
FROM default.orders
WHERE TRY_CAST(quantity AS INT) IS NULL
GROUP BY quantity
ORDER BY cnt DESC;

-- COMMAND ----------

SELECT
    order_amount,
    COUNT(*) AS cnt
FROM default.orders
GROUP BY order_amount
ORDER BY cnt DESC
LIMIT 20;

-- COMMAND ----------

SELECT order_date
FROM default.orders
TABLESAMPLE (0.01 PERCENT)
LIMIT 30;

-- COMMAND ----------

SELECT *
FROM default.orders
WHERE TRY_CAST(REPLACE(order_amount, ',', '') AS DOUBLE) = -50;

-- COMMAND ----------

DESCRIBE default.products;

-- COMMAND ----------

SELECT DISTINCT price
FROM default.products


-- COMMAND ----------

SELECT
    product_id,
    COUNT(*) AS orders_count
FROM default.orders
GROUP BY product_id
ORDER BY RAND()
LIMIT 1;

-- COMMAND ----------

SELECT
    o.order_id,
    o.product_id,
    o.quantity,
    p.price,
    o.order_amount,

    TRY_CAST(REPLACE(p.price, ',', '') AS DOUBLE) AS unit_price,
    TRY_CAST(o.quantity AS INT) AS qty,

    TRY_CAST(REPLACE(p.price, ',', '') AS DOUBLE)
    * TRY_CAST(o.quantity AS INT) AS expected_amount

FROM default.orders o
JOIN default.products p
    ON o.product_id = p.product_id

WHERE o.product_id = 'PROD-0355';

-- COMMAND ----------

SELECT
    order_id,
    customer_id,
    product_id,

    /* Quantity */
    CASE
        WHEN LOWER(TRIM(quantity)) = 'five' THEN 5
        WHEN TRIM(quantity) = '2.0' THEN 2
        WHEN TRIM(quantity) = '' THEN NULL
        WHEN TRY_CAST(quantity AS INT) = -3 THEN NULL
        ELSE TRY_CAST(quantity AS INT)
    END AS quantity,

    /* Order Amount */
    TRY_CAST(
        REPLACE(order_amount, ',', '')
        AS DECIMAL(10,2)
    ) AS order_amount,

    /* Order Date */
    COALESCE(
        TRY_TO_DATE(order_date, "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
        TRY_TO_DATE(order_date, "yyyy-MM-dd"),
        TRY_TO_DATE(order_date, "dd-MM-yyyy")
    ) AS order_date,

    /* Status */
    CASE
        WHEN LOWER(TRIM(status)) = 'ref' THEN 'refunded'
        ELSE LOWER(TRIM(status))
    END AS status,

    /* Payment Method */
    CASE
        WHEN LOWER(TRIM(payment_method)) = 'crad' THEN 'card'
        ELSE LOWER(TRIM(payment_method))
    END AS payment_method

FROM default.orders;

-- COMMAND ----------

select distinct payment_method
 from default.orders

-- COMMAND ----------

SELECT
    order_id,
    customer_id,
    product_id,

    /* Quantity */
    CASE
        WHEN LOWER(TRIM(quantity)) = 'five' THEN 5
        WHEN TRIM(quantity) = '2.0' THEN 2
        WHEN TRIM(quantity) = '' THEN NULL
        WHEN TRY_CAST(quantity AS INT) = -3 THEN NULL
        ELSE TRY_CAST(quantity AS INT)
    END AS quantity,

    /* Order Amount */
    TRY_CAST(
        REPLACE(order_amount, ',', '')
        AS DECIMAL(10,2)
    ) AS order_amount,

    /* Order Date */
    COALESCE(
        TRY_TO_DATE(order_date, "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
        TRY_TO_DATE(order_date, "yyyy-MM-dd"),
        TRY_TO_DATE(order_date, "dd-MM-yyyy")
    ) AS order_date,

    /* Status */
    CASE
        WHEN LOWER(TRIM(status)) IN ('success','suc') THEN 'success'
        WHEN LOWER(TRIM(status)) IN ('failed','fail') THEN 'failed'
        WHEN LOWER(TRIM(status)) IN ('refunded','ref') THEN 'refunded'
        ELSE NULL
    END AS status,

    /* Payment Method */
    CASE
        WHEN LOWER(TRIM(payment_method)) IN ('card','crad','c@rd','cd') THEN 'card'
        WHEN LOWER(TRIM(payment_method)) IN ('wallet','wall-et') THEN 'wallet'
        WHEN LOWER(TRIM(payment_method)) = 'upi' THEN 'upi'
        WHEN LOWER(TRIM(payment_method)) = 'cash' THEN 'cash'
        ELSE NULL
    END AS payment_method

FROM default.orders;

-- COMMAND ----------

SELECT DISTINCT payment_method
FROM (
    SELECT
    order_id,
    customer_id,
    product_id,

    /* Quantity */
    CASE
        WHEN LOWER(TRIM(quantity)) = 'five' THEN 5
        WHEN TRIM(quantity) = '2.0' THEN 2
        WHEN TRIM(quantity) = '' THEN NULL
        WHEN TRY_CAST(quantity AS INT) = -3 THEN NULL
        ELSE TRY_CAST(quantity AS INT)
    END AS quantity,

    /* Order Amount */
    TRY_CAST(
        REPLACE(order_amount, ',', '')
        AS DECIMAL(10,2)
    ) AS order_amount,

    /* Order Date */
    COALESCE(
        TRY_TO_DATE(order_date, "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
        TRY_TO_DATE(order_date, "yyyy-MM-dd"),
        TRY_TO_DATE(order_date, "dd-MM-yyyy")
    ) AS order_date,

    /* Status */
    CASE
        WHEN LOWER(TRIM(status)) IN ('success','suc') THEN 'success'
        WHEN LOWER(TRIM(status)) IN ('failed','fail') THEN 'failed'
        WHEN LOWER(TRIM(status)) IN ('refunded','ref') THEN 'refunded'
        ELSE NULL
    END AS status,

    /* Payment Method */
    CASE
        WHEN LOWER(TRIM(payment_method)) IN ('card','crad','c@rd','cd') THEN 'card'
        WHEN LOWER(TRIM(payment_method)) IN ('wallet','wall-et') THEN 'wallet'
        WHEN LOWER(TRIM(payment_method)) = 'upi' THEN 'upi'
        WHEN LOWER(TRIM(payment_method)) = 'cash' THEN 'cash'
        ELSE NULL
    END AS payment_method

FROM default.orders
);

-- COMMAND ----------

CREATE OR REPLACE TABLE customer360_silver.orders AS

SELECT
    order_id,
    customer_id,
    product_id,

    /* Quantity */
    CASE
        WHEN LOWER(TRIM(quantity)) = 'five' THEN 5
        WHEN TRIM(quantity) = '2.0' THEN 2
        WHEN TRIM(quantity) = '' THEN NULL
        WHEN TRY_CAST(quantity AS INT) = -3 THEN NULL
        ELSE TRY_CAST(quantity AS INT)
    END AS quantity,

    /* Order Amount */
    TRY_CAST(
        REPLACE(order_amount, ',', '')
        AS DECIMAL(10,2)
    ) AS order_amount,

    /* Order Date */
    COALESCE(
        TRY_TO_DATE(order_date, "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
        TRY_TO_DATE(order_date, "yyyy-MM-dd"),
        TRY_TO_DATE(order_date, "dd-MM-yyyy")
    ) AS order_date,

    /* Status */
    CASE
        WHEN LOWER(TRIM(status)) IN ('success','suc') THEN 'success'
        WHEN LOWER(TRIM(status)) IN ('failed','fail') THEN 'failed'
        WHEN LOWER(TRIM(status)) IN ('refunded','ref') THEN 'refunded'
        ELSE NULL
    END AS status,

    /* Payment Method */
    CASE
        WHEN LOWER(TRIM(payment_method)) IN ('card','crad','c@rd','cd') THEN 'card'
        WHEN LOWER(TRIM(payment_method)) IN ('wallet','wall-et') THEN 'wallet'
        WHEN LOWER(TRIM(payment_method)) = 'upi' THEN 'upi'
        WHEN LOWER(TRIM(payment_method)) = 'cash' THEN 'cash'
        ELSE NULL
    END AS payment_method

FROM default.orders;

-- COMMAND ----------

SELECT COUNT(*)
FROM customer360_silver.orders;

-- COMMAND ----------

DESCRIBE customer360_silver.orders;

-- COMMAND ----------

SELECT *
FROM default.products


-- COMMAND ----------

SELECT
  DISTINCT category
FROM default.products

-- COMMAND ----------


SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS product_id_nulls,
    SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS product_name_nulls,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS category_nulls,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS price_nulls
FROM default.products;

-- COMMAND ----------

SELECT *
FROM default.products
ORDER BY product_id



-- COMMAND ----------

SELECT DISTINCT price
FROM default.products
ORDER BY price;

-- COMMAND ----------

SELECT
    COUNT(*) AS negative_prices
FROM default.products
WHERE TRY_CAST(REPLACE(price, ',', '') AS DOUBLE) < 0;

-- COMMAND ----------

SELECT *
FROM default.products
WHERE TRY_CAST(REPLACE(price, ',', '') AS DOUBLE) = 0;

-- COMMAND ----------

SELECT
    category,
    COUNT(*) AS cnt
FROM default.products
WHERE TRY_CAST(REPLACE(price, ',', '') AS DOUBLE) = -100
GROUP BY category;

-- COMMAND ----------

SELECT *
FROM (
    -- حط الكويري هنا
SELECT
    product_id,

    /* Product Name */
    TRIM(product_name) AS product_name,

    /* Category */
    CASE
        WHEN LOWER(TRIM(category)) IN ('clo','clothing','clothing_','clothing-')
            THEN 'clothing'

        WHEN LOWER(TRIM(category)) IN ('ele','electronics','electronics_','3l3ctronics')
            THEN 'electronics'

        WHEN LOWER(TRIM(category)) IN ('aut','automotive','automotive_','automotive-','automotiv3')
            THEN 'automotive'

        WHEN LOWER(TRIM(category)) IN ('hom','home','home_','home-','hom3')
            THEN 'home'

        WHEN LOWER(TRIM(category)) IN ('kit','kitchen','kitchen_','kitchen-','kitch3n')
            THEN 'kitchen'

        WHEN LOWER(TRIM(category)) IN ('toy','toys','toys_','toys-')
            THEN 'toys'

        WHEN LOWER(TRIM(category)) IN ('bea','beauty','beauty_','beauty-','b3auty')
            THEN 'beauty'

        WHEN LOWER(TRIM(category)) IN ('sports','sports_','sports-')
            THEN 'sports'

        ELSE category
    END AS category,

    /* Price */
    TRY_CAST(
        REPLACE(price, ',', '')
        AS DECIMAL(10,2)
    ) AS price

FROM default.products)

-- COMMAND ----------

CREATE OR REPLACE TABLE customer360_silver.products AS

SELECT
    product_id,

    TRIM(product_name) AS product_name,

    CASE
        WHEN LOWER(TRIM(category)) IN ('clo','clothing','clothing_','clothing-') THEN 'clothing'
        WHEN LOWER(TRIM(category)) IN ('ele','electronics','electronics_','3l3ctronics') THEN 'electronics'
        WHEN LOWER(TRIM(category)) IN ('aut','automotive','automotive_','automotive-','automotiv3') THEN 'automotive'
        WHEN LOWER(TRIM(category)) IN ('hom','home','home_','home-','hom3') THEN 'home'
        WHEN LOWER(TRIM(category)) IN ('kit','kitchen','kitchen-','kitch3n') THEN 'kitchen'
        WHEN LOWER(TRIM(category)) IN ('toy','toys','toys-') THEN 'toys'
        WHEN LOWER(TRIM(category)) IN ('bea','beauty','beauty_','beauty-','b3auty') THEN 'beauty'
        WHEN LOWER(TRIM(category)) IN ('sports','sports-') THEN 'sports'
        ELSE category
    END AS category,

    TRY_CAST(REPLACE(price, ',', '') AS DECIMAL(10,2)) AS price

FROM default.products;

-- COMMAND ----------

SELECT DISTINCT category
FROM customer360_silver.products;

-- COMMAND ----------

SELECT DISTINCT
CASE
    WHEN LOWER(TRIM(category)) IN ('clo','clothing','clothing_','clothing-') THEN 'clothing'
    WHEN LOWER(TRIM(category)) IN ('ele','electronics','electronics_','3l3ctronics') THEN 'electronics'
    WHEN LOWER(TRIM(category)) IN ('aut','automotive','automotive_','automotive-','automotiv3') THEN 'automotive'
    WHEN LOWER(TRIM(category)) IN ('hom','home','home_','home-','hom3') THEN 'home'
    WHEN LOWER(TRIM(category)) IN ('kit','kitchen','kitchen-','kitch3n') THEN 'kitchen'
    WHEN LOWER(TRIM(category)) IN ('toy','toys','toys-') THEN 'toys'
    WHEN LOWER(TRIM(category)) IN ('bea','beauty','beauty_','beauty-','b3auty') THEN 'beauty'
    WHEN LOWER(TRIM(category)) IN ('sports','sports-') THEN 'sports'
    ELSE NULL
END AS cleaned_category
FROM default.products;

-- COMMAND ----------

SELECT
    category,
    COUNT(*) AS cnt
FROM customer360_silver.products
GROUP BY category
ORDER BY category DESC;

-- COMMAND ----------

SELECT *



FROM default.tickets


-- COMMAND ----------

DESCRIBE default.tickets;

-- COMMAND ----------

SELECT
    ticket_id,
    ticket_created,
    ticket_resolved,
    resolution_time_hours,

    ROUND(
        (
            UNIX_TIMESTAMP(
                TRY_TO_TIMESTAMP(ticket_resolved)
            )
            -
            UNIX_TIMESTAMP(
                TRY_TO_TIMESTAMP(ticket_created)
            )
        ) / 3600,
        2
    ) AS calculated_hours

FROM default.tickets
WHERE
    ticket_created IS NOT NULL
    AND ticket_resolved IS NOT NULL
LIMIT 100;

-- COMMAND ----------

SELECT
    COUNT(*) AS matched_rows
FROM default.tickets
WHERE
    ticket_created IS NOT NULL
    AND ticket_resolved IS NOT NULL

    AND TRY_TO_TIMESTAMP(ticket_created) <= TRY_TO_TIMESTAMP(ticket_resolved)

    AND ROUND(
        (
            UNIX_TIMESTAMP(TRY_TO_TIMESTAMP(ticket_resolved))
            -
            UNIX_TIMESTAMP(TRY_TO_TIMESTAMP(ticket_created))
        ) / 3600,
        2
    ) = ROUND(resolution_time_hours, 2);

-- COMMAND ----------

SELECT
    COUNT(*) AS mismatched_rows
FROM default.tickets
WHERE
    ticket_created IS NOT NULL
    AND ticket_resolved IS NOT NULL

    AND TRY_TO_TIMESTAMP(ticket_created) <= TRY_TO_TIMESTAMP(ticket_resolved)

    AND ROUND(
        (
            UNIX_TIMESTAMP(TRY_TO_TIMESTAMP(ticket_resolved))
            -
            UNIX_TIMESTAMP(TRY_TO_TIMESTAMP(ticket_created))
        ) / 3600,
        2
    ) <> ROUND(resolution_time_hours, 2);

-- COMMAND ----------

SELECT
    ticket_id,
    ticket_created,
    ticket_resolved,
    resolution_time_hours,

    ROUND(
        (
            UNIX_TIMESTAMP(TRY_TO_TIMESTAMP(ticket_resolved))
            -
            UNIX_TIMESTAMP(TRY_TO_TIMESTAMP(ticket_created))
        ) / 3600,
        2
    ) AS calculated_hours

FROM default.tickets
WHERE
    ticket_created IS NOT NULL
    AND ticket_resolved IS NOT NULL
    AND TRY_TO_TIMESTAMP(ticket_created) <= TRY_TO_TIMESTAMP(ticket_resolved)

    AND ROUND(
        (
            UNIX_TIMESTAMP(TRY_TO_TIMESTAMP(ticket_resolved))
            -
            UNIX_TIMESTAMP(TRY_TO_TIMESTAMP(ticket_created))
        ) / 3600,
        2
    ) <> ROUND(resolution_time_hours, 2)



-- COMMAND ----------

SELECT
    COUNT(*) AS total_checked,

    SUM(
        CASE
            WHEN ROUND(
                (
                    UNIX_TIMESTAMP(ticket_resolved_ts)
                    - UNIX_TIMESTAMP(ticket_created_ts)
                ) / 3600,
                2
            ) = ROUND(resolution_time_hours, 2)
            THEN 1 ELSE 0
        END
    ) AS matched,

    SUM(
        CASE
            WHEN ROUND(
                (
                    UNIX_TIMESTAMP(ticket_resolved_ts)
                    - UNIX_TIMESTAMP(ticket_created_ts)
                ) / 3600,
                2
            ) <> ROUND(resolution_time_hours, 2)
            THEN 1 ELSE 0
        END
    ) AS mismatched

FROM (

    SELECT
        *,
        COALESCE(
            TRY_TO_TIMESTAMP(ticket_created,'yyyy-MM-dd HH:mm:ss'),
            TRY_TO_TIMESTAMP(ticket_created,'MM/dd/yyyy HH:mm'),
            TRY_TO_TIMESTAMP(ticket_created,'dd-MM-yyyy HH:mm')
        ) AS ticket_created_ts,

        COALESCE(
            TRY_TO_TIMESTAMP(ticket_resolved,'yyyy-MM-dd HH:mm:ss'),
            TRY_TO_TIMESTAMP(ticket_resolved,'MM/dd/yyyy HH:mm'),
            TRY_TO_TIMESTAMP(ticket_resolved,'dd-MM-yyyy HH:mm')
        ) AS ticket_resolved_ts

    FROM default.tickets

) t

WHERE
    ticket_created_ts IS NOT NULL
    AND ticket_resolved_ts IS NOT NULL
    AND ticket_created_ts <= ticket_resolved_ts;

-- COMMAND ----------

SELECT
    ticket_created,
    ticket_resolved
FROM default.tickets
LIMIT 20;

-- COMMAND ----------

SELECT
    *,

    TRY_TO_TIMESTAMP(
        REPLACE(ticket_created, 'T', ' '),
        'yyyy-MM-dd HH:mm:ss'
    ) AS ticket_created_ts,

    TRY_TO_TIMESTAMP(
        REPLACE(ticket_resolved, 'T', ' '),
        'yyyy-MM-dd HH:mm:ss'
    ) AS ticket_resolved_ts

FROM default.tickets;

-- COMMAND ----------

SELECT
    COUNT(*) AS total_checked,

    SUM(
        CASE
            WHEN ROUND(
                (
                    UNIX_TIMESTAMP(ticket_resolved_ts)
                    - UNIX_TIMESTAMP(ticket_created_ts)
                ) / 3600,
                2
            ) = ROUND(resolution_time_hours, 2)
            THEN 1
            ELSE 0
        END
    ) AS matched,

    SUM(
        CASE
            WHEN ROUND(
                (
                    UNIX_TIMESTAMP(ticket_resolved_ts)
                    - UNIX_TIMESTAMP(ticket_created_ts)
                ) / 3600,
                2
            ) <> ROUND(resolution_time_hours, 2)
            THEN 1
            ELSE 0
        END
    ) AS mismatched

FROM (

    SELECT
        *,
        TRY_TO_TIMESTAMP(
            REPLACE(ticket_created, 'T', ' '),
            'yyyy-MM-dd HH:mm:ss'
        ) AS ticket_created_ts,

        TRY_TO_TIMESTAMP(
            REPLACE(ticket_resolved, 'T', ' '),
            'yyyy-MM-dd HH:mm:ss'
        ) AS ticket_resolved_ts

    FROM default.tickets

) t

WHERE
    ticket_created_ts IS NOT NULL
    AND ticket_resolved_ts IS NOT NULL
    AND ticket_created_ts <= ticket_resolved_ts;

-- COMMAND ----------

select distinct support_agent from default.tickets order by support_agent


-- COMMAND ----------

SELECT
    ticket_id,
    ticket_created,
    ticket_resolved,
    resolution_time_hours
FROM (
    SELECT *,
           TRY_TO_TIMESTAMP(
               REPLACE(ticket_created, 'T', ' '),
               'yyyy-MM-dd HH:mm:ss'
           ) AS ticket_created_ts
    FROM default.tickets
) t
WHERE ticket_created_ts > CURRENT_TIMESTAMP();

-- COMMAND ----------

SELECT
    ticket_id,
    ticket_created,
    ticket_resolved,
    resolution_time_hours
FROM (
    SELECT
        *,
        TRY_TO_TIMESTAMP(
            REPLACE(ticket_created, 'T', ' '),
            'yyyy-MM-dd HH:mm:ss'
        ) AS created_ts,

        TRY_TO_TIMESTAMP(
            REPLACE(ticket_resolved, 'T', ' '),
            'yyyy-MM-dd HH:mm:ss'
        ) AS resolved_ts
    FROM default.tickets
) t
WHERE
    created_ts IS NOT NULL
    AND resolved_ts IS NOT NULL
    AND created_ts > resolved_ts;

-- COMMAND ----------

select distinct issue_type from default.tickets order by issue_type

-- COMMAND ----------

SELECT
    ticket_id,
    ticket_created,
    ticket_resolved,
    resolution_time_hours
FROM default.tickets
WHERE
    ticket_created >
     ticket_resolved

-- COMMAND ----------

SELECT
    ticket_id,
    customer_id,
    issue_type,

    ticket_created_ts AS ticket_created,
    ticket_resolved_ts AS ticket_resolved,

    resolution_time_hours,
    sentiment,
    support_agent

FROM (

    SELECT
        *,

        TRY_TO_TIMESTAMP(
            REPLACE(ticket_created,'T',' '),
            'yyyy-MM-dd HH:mm:ss'
        ) AS ticket_created_ts,

        TRY_TO_TIMESTAMP(
            REPLACE(ticket_resolved,'T',' '),
            'yyyy-MM-dd HH:mm:ss'
        ) AS ticket_resolved_ts

    FROM default.tickets

) t

WHERE NOT (
        ticket_created_ts IS NULL
    AND ticket_resolved_ts IS NULL
)
AND NOT (
        ticket_created_ts IS NOT NULL
    AND ticket_resolved_ts IS NOT NULL
    AND ticket_created_ts > ticket_resolved_ts
);

-- COMMAND ----------

SELECT

    ticket_id,
    customer_id,

    /* Issue Type */
    CASE
        WHEN LOWER(TRIM(issue_type)) IN ('product','pro','product_','productx','tcudorp')
            THEN 'Product'

        WHEN LOWER(TRIM(issue_type)) IN ('payment','pay','payment_','paymentx','paym3nt','tnemyap')
            THEN 'Payment'

        WHEN LOWER(TRIM(issue_type)) IN ('delay','del','delay_','delayx','d3lay','yaled')
            THEN 'Delay'

        WHEN LOWER(TRIM(issue_type)) IN ('refund','ref','refund_','refundx','r3fund','dnufer')
            THEN 'Refund'

        ELSE NULL
    END AS issue_type,

    /* Ticket Created */
    COALESCE(
        TRY_TO_TIMESTAMP(REPLACE(ticket_created,'T',' '),'yyyy-MM-dd HH:mm:ss'),

        TIMESTAMPADD(
            HOUR,
            -CAST(resolution_time_hours AS INT),
            TRY_TO_TIMESTAMP(REPLACE(ticket_resolved,'T',' '),'yyyy-MM-dd HH:mm:ss')
        )

    ) AS ticket_created,

    /* Ticket Resolved */
    COALESCE(
        TRY_TO_TIMESTAMP(REPLACE(ticket_resolved,'T',' '),'yyyy-MM-dd HH:mm:ss'),

        TIMESTAMPADD(
            HOUR,
            CAST(resolution_time_hours AS INT),
            TRY_TO_TIMESTAMP(REPLACE(ticket_created,'T',' '),'yyyy-MM-dd HH:mm:ss')
        )

    ) AS ticket_resolved,

    resolution_time_hours,

    /* Sentiment */
    CASE
        WHEN LOWER(TRIM(sentiment)) IN ('positive','pos','positiv3')
            THEN 'Positive'

        WHEN LOWER(TRIM(sentiment)) IN ('negative','neg','n3gativ3')
            THEN 'Negative'

        WHEN LOWER(TRIM(sentiment)) IN ('neutral','neu','n3utral')
            THEN 'Neutral'

        ELSE NULL
    END AS sentiment,

    /* Support Agent */
    INITCAP(
        LOWER(
            TRIM(
                REGEXP_REPLACE(
                    support_agent,
                    '[^A-Za-z ]',
                    ''
                )
            )
        )
    ) AS support_agent

FROM default.tickets;

-- COMMAND ----------

SELECT
MIN(resolution_time_hours),
MAX(resolution_time_hours),
COUNT(*)
FROM default.tickets
WHERE resolution_time_hours <> FLOOR(resolution_time_hours);

-- COMMAND ----------

SELECT
TIMESTAMPADD(
    HOUR,
    5,
    TIMESTAMP('2024-01-01 10:00:00')
);

-- COMMAND ----------

WITH cleaned AS (

SELECT

    ticket_id,
    customer_id,

    CASE
        WHEN LOWER(TRIM(issue_type)) IN ('product','pro','product_','productx','tcudorp')
            THEN 'Product'
        WHEN LOWER(TRIM(issue_type)) IN ('payment','pay','payment_','paymentx','paym3nt','tnemyap')
            THEN 'Payment'
        WHEN LOWER(TRIM(issue_type)) IN ('delay','del','delay_','delayx','d3lay','yaled')
            THEN 'Delay'
        WHEN LOWER(TRIM(issue_type)) IN ('refund','ref','refund_','refundx','r3fund','dnufer')
            THEN 'Refund'
        ELSE NULL
    END AS issue_type,

    COALESCE(
        TRY_TO_TIMESTAMP(REPLACE(ticket_created,'T',' '),'yyyy-MM-dd HH:mm:ss'),
        TIMESTAMPADD(
            HOUR,
            -CAST(resolution_time_hours AS INT),
            TRY_TO_TIMESTAMP(REPLACE(ticket_resolved,'T',' '),'yyyy-MM-dd HH:mm:ss')
        )
    ) AS ticket_created,

    COALESCE(
        TRY_TO_TIMESTAMP(REPLACE(ticket_resolved,'T',' '),'yyyy-MM-dd HH:mm:ss'),
        TIMESTAMPADD(
            HOUR,
            CAST(resolution_time_hours AS INT),
            TRY_TO_TIMESTAMP(REPLACE(ticket_created,'T',' '),'yyyy-MM-dd HH:mm:ss')
        )
    ) AS ticket_resolved,

    resolution_time_hours,

    CASE
        WHEN LOWER(TRIM(sentiment)) IN ('positive','pos','positiv3') THEN 'Positive'
        WHEN LOWER(TRIM(sentiment)) IN ('negative','neg','n3gativ3') THEN 'Negative'
        WHEN LOWER(TRIM(sentiment)) IN ('neutral','neu','n3utral') THEN 'Neutral'
        ELSE NULL
    END AS sentiment,

    INITCAP(
        LOWER(
            TRIM(
                REGEXP_REPLACE(support_agent,'[^A-Za-z ]','')
            )
        )
    ) AS support_agent

FROM default.tickets

)

SELECT DISTINCT support_agent
FROM cleaned
ORDER BY support_agent;

-- COMMAND ----------

CREATE OR REPLACE TABLE customer360_silver.support_tickets AS

SELECT

    ticket_id,
    customer_id,

    /* Issue Type */
    CASE
        WHEN LOWER(TRIM(issue_type)) IN ('product','pro','product_','productx','tcudorp')
            THEN 'Product'

        WHEN LOWER(TRIM(issue_type)) IN ('payment','pay','payment_','paymentx','paym3nt','tnemyap')
            THEN 'Payment'

        WHEN LOWER(TRIM(issue_type)) IN ('delay','del','delay_','delayx','d3lay','yaled')
            THEN 'Delay'

        WHEN LOWER(TRIM(issue_type)) IN ('refund','ref','refund_','refundx','r3fund','dnufer')
            THEN 'Refund'

        ELSE NULL
    END AS issue_type,

    /* Ticket Created */
    COALESCE(
        TRY_TO_TIMESTAMP(
            REPLACE(ticket_created,'T',' '),
            'yyyy-MM-dd HH:mm:ss'
        ),

        TIMESTAMPADD(
            HOUR,
            -CAST(resolution_time_hours AS INT),
            TRY_TO_TIMESTAMP(
                REPLACE(ticket_resolved,'T',' '),
                'yyyy-MM-dd HH:mm:ss'
            )
        )

    ) AS ticket_created,

    /* Ticket Resolved */
    COALESCE(
        TRY_TO_TIMESTAMP(
            REPLACE(ticket_resolved,'T',' '),
            'yyyy-MM-dd HH:mm:ss'
        ),

        TIMESTAMPADD(
            HOUR,
            CAST(resolution_time_hours AS INT),
            TRY_TO_TIMESTAMP(
                REPLACE(ticket_created,'T',' '),
                'yyyy-MM-dd HH:mm:ss'
            )
        )

    ) AS ticket_resolved,

    resolution_time_hours,

    /* Sentiment */
    CASE
        WHEN LOWER(TRIM(sentiment)) IN ('positive','pos','positiv3')
            THEN 'Positive'

        WHEN LOWER(TRIM(sentiment)) IN ('negative','neg','n3gativ3')
            THEN 'Negative'

        WHEN LOWER(TRIM(sentiment)) IN ('neutral','neu','n3utral')
            THEN 'Neutral'

        ELSE NULL
    END AS sentiment,

    /* Support Agent */
    INITCAP(
        LOWER(
            TRIM(
                REGEXP_REPLACE(
                    support_agent,
                    '[^A-Za-z ]',
                    ''
                )
            )
        )
    ) AS support_agent

FROM default.tickets;

-- COMMAND ----------

SELECT
SUM(CASE WHEN ticket_created IS NULL THEN 1 ELSE 0 END) AS created_nulls,
SUM(CASE WHEN ticket_resolved IS NULL THEN 1 ELSE 0 END) AS resolved_nulls
FROM customer360_silver.support_tickets;

-- COMMAND ----------

SELECT

SUM(
CASE
WHEN ticket_created IS NULL
AND ticket_resolved IS NULL
THEN 1 ELSE 0
END
) AS both_null,

SUM(
CASE
WHEN ticket_created IS NULL
AND ticket_resolved IS NOT NULL
THEN 1 ELSE 0
END
) AS created_only,

SUM(
CASE
WHEN ticket_created IS NOT NULL
AND ticket_resolved IS NULL
THEN 1 ELSE 0
END
) AS resolved_only

FROM customer360_silver.support_tickets;

-- COMMAND ----------

SELECT COUNT(*) AS invalid_dates
FROM customer360_silver.support_tickets
WHERE
    ticket_created IS NOT NULL
    AND ticket_resolved IS NOT NULL
    AND ticket_created > ticket_resolved;

-- COMMAND ----------

SHOW TABLES IN default;

-- COMMAND ----------

SHOW TABLES IN customer360_silver;

-- COMMAND ----------

DESCRIBE default.clickstream;

-- COMMAND ----------

select * from default.clickstream where timestamp

is null

-- COMMAND ----------

SELECT
SUM(CASE WHEN event_id IS NULL THEN 1 ELSE 0 END) AS event_id_nulls,
SUM(CASE WHEN session_id IS NULL THEN 1 ELSE 0 END) AS session_id_nulls,
SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS customer_id_nulls,
SUM(CASE WHEN event_type IS NULL THEN 1 ELSE 0 END) AS event_type_nulls,
SUM(CASE WHEN page_url IS NULL THEN 1 ELSE 0 END) AS page_url_nulls,
SUM(CASE WHEN device_id IS NULL THEN 1 ELSE 0 END) AS device_id_nulls,
SUM(CASE WHEN timestamp IS NULL THEN 1 ELSE 0 END) AS timestamp_nulls,
SUM(CASE WHEN ingest_run_id IS NULL THEN 1 ELSE 0 END) AS ingest_run_id_nulls
FROM default.clickstream;

-- COMMAND ----------

SELECT DISTINCT timestamp
FROM default.clickstream;

-- COMMAND ----------

SELECT *
FROM default.clickstream
WHERE timestamp IS NULL;

-- COMMAND ----------

SELECT
COUNT(*) AS total_records,

SUM(CASE WHEN timestamp IS NULL THEN 1 ELSE 0 END) AS timestamp_nulls,

ROUND(
    SUM(CASE WHEN timestamp IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
    2
) AS null_percentage

FROM default.clickstream;

-- COMMAND ----------

select distinct event_type,   ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM default.clickstream where timestamp is null),
        2)
from default.clickstream
where timestamp is null
group by event_type


-- COMMAND ----------

SELECT
event_type,
COUNT(*) cnt
FROM default.clickstream
WHERE page_url IS NULL
GROUP BY event_type


-- COMMAND ----------

CREATE OR REPLACE TABLE customer360_silver.clickstream AS

SELECT

    event_id,

    session_id,

    customer_id,

    INITCAP(
        LOWER(
            TRIM(event_type)
        )
    ) AS event_type,

    TRIM(page_url) AS page_url,

    TRIM(device_id) AS device_id,

    TRY_TO_TIMESTAMP(
        REPLACE(timestamp,'T',' '),
        'yyyy-MM-dd HH:mm:ss'
    ) AS timestamp

FROM default.clickstream;

-- COMMAND ----------

DESCRIBE customer360_silver.customers;

-- COMMAND ----------

select distinct status from customer360_silver.orders

-- COMMAND ----------

CREATE OR REPLACE TABLE customer360_gold.fact_orders AS

SELECT

    o.order_id,

    dc.customer_key,

    dp.product_key,

    dd.date_key,

    o.quantity,

    o.order_amount,

    o.payment_method,

    o.status

FROM customer360_silver.orders o

LEFT JOIN customer360_gold.dim_customer dc
    ON o.customer_id = dc.customer_id

LEFT JOIN customer360_gold.dim_product dp
    ON o.product_id = dp.product_id

LEFT JOIN customer360_gold.dim_date dd
    ON CAST(o.order_date AS DATE) = dd.full_date;

-- COMMAND ----------

SELECT
SUM(order_amount)
FROM customer360_gold.fact_orders
WHERE status = 'success';


-- COMMAND ----------

SELECT
MIN(order_amount) AS min_amount,
MAX(order_amount) AS max_amount,
AVG(order_amount) AS avg_amount
FROM customer360_gold.fact_orders
WHERE status='success';

-- COMMAND ----------

SELECT
order_id,
product_key,
quantity,
order_amount
FROM customer360_gold.fact_orders
WHERE status = 'success'
ORDER BY order_amount DESC
LIMIT 100;