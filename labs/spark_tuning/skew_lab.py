"""E3 Spark tuning lab: data skew in a join.

Builds an 'orders' table where one customer owns most rows, joins it to 'customers',
and times the query. Run with --scenario skewed | aqe | salted and compare.
"""

import argparse
import time

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

SALT_BUCKETS = 8


def parse_args():
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--scenario", required=True, choices=["skewed", "aqe", "salted"])
    parser.add_argument("--rows", type=int, default=20_000_000)
    parser.add_argument("--hot_share", type=float, default=0.8)
    args, _unknown = parser.parse_known_args()
    return args


args = parse_args()

builder = (
    SparkSession.builder.appName(f"skew-lab-{args.scenario}")
    # Force a shuffle (sort-merge) join; otherwise Spark would broadcast the small table and hide the skew.
    .config("spark.sql.autoBroadcastJoinThreshold", "-1")
)
if args.scenario == "aqe":
    # Adaptive Query Execution splits oversized partitions at runtime.
    # Lower thresholds so the lab-sized data counts as "skewed".
    builder = (
        builder.config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.adaptive.skewJoin.enabled", "true")
        .config("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "32m")
        .config("spark.sql.adaptive.advisoryPartitionSizeInBytes", "16m")
    )
else:
    # Baseline and manual salting: AQE off, so we see the raw behavior.
    builder = builder.config("spark.sql.adaptive.enabled", "false")

spark = builder.getOrCreate()

# 80% of orders belong to customer 1 (the "hot key"); the rest spread over 1M customers.
orders = spark.range(args.rows).select(
    F.col("id").alias("order_id"),
    F.when(F.rand(seed=42) < args.hot_share, F.lit(1))
    .otherwise((F.rand(seed=7) * 1_000_000).cast("long") + 2)
    .alias("customer_id"),
    (F.rand(seed=1) * 100).alias("amount"),
)
customers = spark.range(1, 1_000_002).select(
    F.col("id").alias("customer_id"),
    (F.col("id") % 50).alias("segment"),
)

if args.scenario == "salted":
    # Spread each customer_id over SALT_BUCKETS keys: orders get a random salt,
    # customers are copied once per salt value so every (customer_id, salt) pair still matches.
    orders = orders.withColumn("salt", (F.rand(seed=3) * SALT_BUCKETS).cast("int"))
    salts = spark.range(SALT_BUCKETS).select(F.col("id").cast("int").alias("salt"))
    customers = customers.crossJoin(salts)
    joined = orders.join(customers, ["customer_id", "salt"])
else:
    joined = orders.join(customers, "customer_id")

result = joined.groupBy("segment").agg(F.sum("amount").alias("revenue"), F.count("*").alias("orders"))

start = time.perf_counter()
rows = result.collect()
seconds = time.perf_counter() - start

print(f"[lab] scenario={args.scenario} rows={args.rows} segments={len(rows)} seconds={seconds:.1f}")
