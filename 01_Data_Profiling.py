# Databricks notebook source
customers_df = spark.read.format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .load("/Volumes/workspace/default/customer360_raw/crm_50000_customers_dirty_v3.csv")

display(customers_df)

# COMMAND ----------

len(customers_df.columns)

# COMMAND ----------

customers_df.printSchema()

# COMMAND ----------

from pyspark.sql.functions import col

customers_df.filter(col("customer_id").isNull()).count()

# COMMAND ----------

from pyspark.sql.functions import col, count, when

customers_df.select([
    count(when(col(c).isNull(), c)).alias(c)
    for c in customers_df.columns
]).show()

# COMMAND ----------

customers_df.count()

# COMMAND ----------

from pyspark.sql.functions import count

duplicate_ids = (
    customers_df
    .groupBy("customer_id")
    .agg(count("*").alias("count"))
    .filter(col("count") > 1)
)

duplicate_ids.show()

# COMMAND ----------

duplicate_ids.count()

# COMMAND ----------

duplicate_ids.orderBy(col("count").desc()).show(20, truncate=False)

# COMMAND ----------

duplicate_percentage = (duplicate_ids.count() / customers_df.count()) * 100

print(f"Duplicate IDs: {duplicate_percentage:.2f}%")

# COMMAND ----------

duplicate_records = customers_df.join(
    duplicate_ids.select("customer_id"),
    on="customer_id",
    how="inner"
)

display(duplicate_records.orderBy("customer_id"))

# COMMAND ----------

from pyspark.sql.functions import col, count, when

duplicate_records.groupBy("customer_id").agg(
    count("*").alias("records"),
    count(when(col("email").isNull(), 1)).alias("null_emails")
).show()

# COMMAND ----------

summary = (
    duplicate_records
    .groupBy("customer_id")
    .agg(
        count("*").alias("records"),
        count(when(col("email").isNull(), 1)).alias("null_emails")
    )
    .groupBy("null_emails")
    .count()
    .orderBy("null_emails")
)

display(summary)

# COMMAND ----------

duplicate_records.filter(
    col("customer_id") == "ضع الـ customer_id هنا"
).select(
    "customer_id",
    "first_name",
    "last_name"
).show(truncate=False)

# COMMAND ----------

from pyspark.sql.functions import col

display(
    customers_df.filter(col("first_name").rlike("[0-9]"))
)

# COMMAND ----------

display(
    customers_df.filter(col("last_name").rlike("[0-9]"))
)

# COMMAND ----------

non_duplicate_records = customers_df.join(
    duplicate_ids.select("customer_id"),
    on="customer_id",
    how="left_anti"
)

# COMMAND ----------

non_duplicate_records.filter(
    col("first_name").rlike("[0-9]")
).count()

# COMMAND ----------

from pyspark.sql.functions import col

customers_df.filter(
    col("signup_date") < col("dob")
).count()

# COMMAND ----------

from pyspark.sql.functions import col, current_date

customers_df.filter(
    col("dob") > current_date()
).count()

# COMMAND ----------

from pyspark.sql.functions import col, current_date

customers_df.filter(
    col("dob") > current_date()
).count()

# COMMAND ----------

customers_df.filter(
    col("signup_date") > current_date()
).count()

# COMMAND ----------

orders_df = spark.read.format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .load("/Volumes/workspace/default/customer360_raw/orders_300k_dirty.csv")

display(orders_df)

# COMMAND ----------

from pyspark.sql.functions import col

duplicate_orders = (
    orders_df.groupBy("order_id")
    .count()
    .filter(col("count") > 1)
)

duplicate_orders.count()

# COMMAND ----------

orders_df.printSchema()

# COMMAND ----------

from pyspark.sql.functions import expr

negative_products = (
    orders_df
    .filter(expr("try_cast(order_amount as double) < 0"))
    .select("product_id")
    .distinct()
)

display(negative_products)

# COMMAND ----------

from pyspark.sql.functions import expr, max, when

orders_df.groupBy("product_id").agg(
    max(when(expr("try_cast(order_amount as double) < 0"), 1).otherwise(0)).alias("has_negative"),
    max(when(expr("try_cast(order_amount as double) > 0"), 1).otherwise(0)).alias("has_positive")
).filter(
    col("has_negative") == 1
).show(truncate=False)

# COMMAND ----------

from pyspark.sql.functions import col, expr, max, when

product_check = orders_df.groupBy("product_id").agg(
    max(when(expr("try_cast(order_amount as double) < 0"), 1).otherwise(0)).alias("has_negative"),
    max(when(expr("try_cast(order_amount as double) > 0"), 1).otherwise(0)).alias("has_positive")
)

product_check.groupBy("has_negative", "has_positive").count().show()

# COMMAND ----------

from pyspark.sql.functions import expr

orders_df.filter(
    expr("try_cast(order_amount as double) < 0")
).groupBy("status").count().show()

# COMMAND ----------

from pyspark.sql.functions import col, trim

display(
    orders_df.filter(
        trim(col("status")).isin("REF", "refunded", " refunded")
    )
)

# COMMAND ----------

from pyspark.sql.functions import expr

display(
    orders_df.filter(
        col("product_id") == "PROD-XXXX"
    ).orderBy("customer_id", "order_date")
)

# COMMAND ----------

from pyspark.sql.functions import expr, abs, col

orders_amount = orders_df.withColumn(
    "amount_num",
    expr("try_cast(order_amount as double)")
)

display(
    orders_amount
    .withColumn("abs_amount", abs(col("amount_num")))
    .groupBy("product_id", "abs_amount")
    .count()
    .filter(col("count") > 1)
    .orderBy("product_id", "abs_amount")
)

# COMMAND ----------

display(
    result.orderBy(col("product_id").asc(), col("abs_amount").desc())
)

# COMMAND ----------

from pyspark.sql.functions import col, expr, abs, max, when

orders_amount = orders_df.withColumn(
    "amount_num",
    expr("try_cast(order_amount as double)")
)

result = (
    orders_amount
    .withColumn("abs_amount", abs(col("amount_num")))
    .groupBy("product_id", "abs_amount")
    .agg(
        max(when(col("amount_num") > 0, 1).otherwise(0)).alias("has_positive"),
        max(when(col("amount_num") < 0, 1).otherwise(0)).alias("has_negative")
    )
    .filter(
        (col("has_positive") == 1) &
        (col("has_negative") == 1)
    )
)

# COMMAND ----------

result.orderBy("product_id", "abs_amount").show(1000, truncate=False)

# COMMAND ----------

from pyspark.sql.functions import col, expr, max, when

orders_amount = orders_df.withColumn(
    "amount_num",
    expr("try_cast(order_amount as double)")
)

products_with_both = (
    orders_amount
    .groupBy("product_id")
    .agg(
        max(when(col("amount_num") > 0, 1).otherwise(0)).alias("has_positive"),
        max(when(col("amount_num") < 0, 1).otherwise(0)).alias("has_negative")
    )
    .filter(
        (col("has_positive") == 1) &
        (col("has_negative") == 1)
    )
)

display(products_with_both.orderBy("product_id"))

# COMMAND ----------

orders_df.select("product_id").distinct().count()

# COMMAND ----------

from pyspark.sql.functions import expr

display(
    orders_df.filter(
        expr("try_cast(order_amount as double) < 0")
    ).select("customer_id").distinct()
)

# COMMAND ----------

from pyspark.sql.functions import count, expr

display(
    orders_df.filter(
        expr("try_cast(order_amount as double) < 0")
    )
    .groupBy("customer_id")
    .agg(count("*").alias("negative_orders"))
    .orderBy("negative_orders", ascending=False)
)

# COMMAND ----------

from pyspark.sql.functions import expr, when, sum

display(
    orders_df
    .withColumn(
        "is_negative",
        when(expr("try_cast(order_amount as double) < 0"), 1).otherwise(0)
    )
    .groupBy("customer_id")
    .agg(
        sum("is_negative").alias("negative_orders"),
        expr("count(*) - sum(is_negative)").alias("positive_orders")
    )
)

# COMMAND ----------

from pyspark.sql.functions import expr

negative_customers = orders_df.filter(
    expr("try_cast(order_amount as double) < 0")
).select("customer_id").distinct()

total_customers = orders_df.select("customer_id").distinct().count()

negative_count = negative_customers.count()

print(f"Customers with negative orders: {negative_count}")
print(f"Total customers: {total_customers}")
print(f"Percentage: {negative_count / total_customers * 100:.2f}%")

# COMMAND ----------

from pyspark.sql.functions import expr, when, count

display(
    orders_df.withColumn(
        "amount_type",
        when(expr("try_cast(order_amount as double) < 0"), "Negative")
        .otherwise("Positive")
    )
    .groupBy("payment_method", "amount_type")
    .agg(count("*").alias("orders"))
    .orderBy("payment_method", "amount_type")
)

# COMMAND ----------

display(
    orders_df.filter(col("product_id") == "PROD-0371")
)

# COMMAND ----------

from pyspark.sql.functions import col, count, when

display(
    orders_df.select([
        count(when(col(c).isNull() | (col(c) == ""), c)).alias(c)
        for c in orders_df.columns
    ])
)

# COMMAND ----------

products_df = spark.read.format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .load("/Volumes/workspace/default/customer360_raw/product_catalog_dirty_30pct.csv")

display(products_df)

# COMMAND ----------

from pyspark.sql.functions import col, count, when, trim

display(
    products_df.select([
        count(
            when(
                col(c).isNull() | (trim(col(c)) == ""),
                c
            )
        ).alias(c)
        for c in products_df.columns
    ])
)

# COMMAND ----------

products_df.groupBy("product_id") \
    .count() \
    .filter("count > 1") \
    .count()

# COMMAND ----------


products_df = spark.read.format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .load("/Volumes/workspace/default/customer360_raw/product_catalog_dirty_30pct.csv")

display(products_df)

# COMMAND ----------

products_df.createOrReplaceTempView("products")

# COMMAND ----------

products_df = spark.read.format("csv") \
.option("header","true") \
.option("inferSchema","true") \
.load("/Volumes/workspace/default/customer360_raw/product_catalog_dirty_30pct.csv")

# COMMAND ----------

display(products_df)

# COMMAND ----------

print("products_df" in globals())

# COMMAND ----------

products_df.printSchema()

# COMMAND ----------

display(
    products_df.groupBy("category")
        .count()
        .orderBy("count", ascending=False)
)

# COMMAND ----------

from pyspark.sql.functions import expr

display(
    products_df
    .withColumn("price_num", expr("try_cast(price as double)"))
    .filter("price_num < 0")
    .groupBy("category")
    .count()
    .orderBy("count", ascending=False)
)

# COMMAND ----------

tickets_df = spark.read.format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .load("/Volumes/workspace/default/customer360_raw/support_tickets_30000_dirty.csv")

display(tickets_df)

# COMMAND ----------

tickets_df.printSchema()

# COMMAND ----------

tickets_df.groupBy("ticket_id") \
    .count() \
    .filter("count > 1") \
    .count()

# COMMAND ----------

from pyspark.sql.functions import col, count, when, trim

display(
    tickets_df.select([
        count(
            when(
                col(c).isNull() | (trim(col(c)) == ""),
                c
            )
        ).alias(c)
        for c in tickets_df.columns
    ])
)

# COMMAND ----------

display(
    tickets_df.select("issue_type")
        .distinct()
        .orderBy("issue_type")
)

# COMMAND ----------

display(
    tickets_df.filter(tickets_df.resolution_time_hours < 0)
)

# COMMAND ----------

from pyspark.sql.functions import expr

display(
    tickets_df
    .withColumn("created_ts", expr("try_to_timestamp(ticket_created)"))
    .withColumn("resolved_ts", expr("try_to_timestamp(ticket_resolved)"))
    .filter("created_ts > resolved_ts")
    .select(
        "ticket_id",
        "ticket_created",
        "ticket_resolved",
        "created_ts",
        "resolved_ts"
    )
)

# COMMAND ----------

display(
    tickets_df.select("issue_type")
        .distinct()
        .orderBy("issue_type")
)

# COMMAND ----------

from pyspark.sql.functions import expr, current_timestamp

display(
    tickets_df
    .withColumn("created_ts", expr("try_to_timestamp(ticket_created)"))
    .withColumn("resolved_ts", expr("try_to_timestamp(ticket_resolved)"))
    .filter(
        (expr("created_ts > current_timestamp()")) |
        (expr("resolved_ts > current_timestamp()"))
    )
    .select(
        "ticket_id",
        "ticket_created",
        "ticket_resolved"
    )
)

# COMMAND ----------

clickstream_df = spark.read.format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .load("/Volumes/workspace/default/customer360_raw/clickstream_500k_events.csv")

# COMMAND ----------

clickstream_df.createOrReplaceTempView("clickstream")

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT COUNT(*)
# MAGIC FROM clickstream;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT *
# MAGIC FROM clickstream;

# COMMAND ----------

clickstream_df.printSchema()

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT
# MAGIC     COUNT(CASE WHEN event_id IS NULL OR TRIM(event_id) = '' THEN 1 END) AS event_id_nulls,
# MAGIC     COUNT(CASE WHEN session_id IS NULL OR TRIM(session_id) = '' THEN 1 END) AS session_id_nulls,
# MAGIC     COUNT(CASE WHEN customer_id IS NULL OR TRIM(customer_id) = '' THEN 1 END) AS customer_id_nulls,
# MAGIC     COUNT(CASE WHEN event_type IS NULL OR TRIM(event_type) = '' THEN 1 END) AS event_type_nulls,
# MAGIC     COUNT(CASE WHEN page_url IS NULL OR TRIM(page_url) = '' THEN 1 END) AS page_url_nulls,
# MAGIC     COUNT(CASE WHEN device_id IS NULL OR TRIM(device_id) = '' THEN 1 END) AS device_id_nulls,
# MAGIC     COUNT(CASE WHEN timestamp IS NULL OR TRIM(timestamp) = '' THEN 1 END) AS timestamp_nulls,
# MAGIC     COUNT(CASE WHEN ingest_run_id IS NULL OR TRIM(ingest_run_id) = '' THEN 1 END) AS ingest_run_id_nulls
# MAGIC FROM clickstream;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT COUNT(*) AS duplicate_event_ids
# MAGIC FROM (
# MAGIC     SELECT event_id
# MAGIC     FROM clickstream
# MAGIC     GROUP BY event_id
# MAGIC     HAVING COUNT(*) > 1
# MAGIC ) t;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT
# MAGIC     event_type,
# MAGIC     COUNT(*) AS cnt
# MAGIC FROM clickstream
# MAGIC
# MAGIC GROUP BY event_type
# MAGIC ORDER BY cnt DESC;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT
# MAGIC     event_type,
# MAGIC     COUNT(*) AS cnt
# MAGIC FROM clickstream
# MAGIC WHERE page_url IS NULL
# MAGIC GROUP BY event_type
# MAGIC ORDER BY cnt DESC;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT
# MAGIC     event_type,
# MAGIC     COUNT(*) AS cnt
# MAGIC FROM clickstream
# MAGIC WHERE timestamp IS NULL
# MAGIC GROUP BY event_type
# MAGIC ORDER BY cnt DESC;

# COMMAND ----------

# MAGIC %sql
# MAGIC select distinct(ingest_run_id
# MAGIC )
# MAGIC from clickstream