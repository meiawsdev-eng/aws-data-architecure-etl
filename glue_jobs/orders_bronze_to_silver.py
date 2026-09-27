"""Bronze -> Silver ETL for orders.

Reads one day's raw CSV delivery, cleans it, and MERGEs it into the silver.orders Iceberg table.
Idempotent: re-running for the same ingest_date leaves the table in the same state.
"""
import argparse
import sys

from pyspark.sql import SparkSession, Window
from pyspark.sql import functions as F

# 1. Parameters (passed by Glue as --ingest_date, --raw_bucket, --clean_bucket)
# 1. Parameters (--ingest_date, --raw_bucket, --clean_bucket). argparse works on Glue and EMR alike.
def parse_args(argv):
    """Read our parameters; ignore extra args the engine adds (e.g. Glue passes --JOB_NAME, --TempDir)."""
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--ingest_date", required=True)
    parser.add_argument("--raw_bucket", required=True)
    parser.add_argument("--clean_bucket", required=True)
    args, _unknown = parser.parse_known_args(argv)
    return args


args = parse_args(sys.argv[1:])
ingest_date = args.ingest_date


# 2. Spark session with an Iceberg catalog backed by the Glue Data Catalog
spark = (
    SparkSession.builder
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
    .config("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.glue_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog")
    .config("spark.sql.catalog.glue_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
    .config("spark.sql.catalog.glue_catalog.warehouse", f"s3://{args.clean_bucket}/")
    .getOrCreate()
)

# 3. Extract: exactly one raw partition, every column as string
raw_path = f"s3://{args.raw_bucket}/orders/ingest_date={ingest_date}/"
raw = spark.read.option("header", "true").csv(raw_path)
print(f"[extract] {raw.count()} raw rows from {raw_path}")


# 4. Transform
def blank_to_null(col_name):
    c = F.trim(F.col(col_name))
    return F.when(c == "", None).otherwise(c)


typed = raw.select(
    F.col("order_id").cast("int").alias("order_id"),
    blank_to_null("customer_id").alias("customer_id"),
    F.to_date(F.trim("order_date")).alias("order_date"),
    F.expr("try_cast(trim(amount) AS decimal(12,2))").alias("amount"),
    F.lower(F.trim("status")).alias("status"),
    F.to_timestamp(F.trim("updated_at")).alias("updated_at"),
    blank_to_null("amount").alias("_raw_amount"),
).filter(F.col("order_id").isNotNull())

dq = F.concat_ws(
    ",",
    F.when(F.col("amount").isNull() & F.col("_raw_amount").isNotNull(), F.lit("invalid_amount")),
    F.when(F.col("customer_id").isNull(), F.lit("missing_customer_id")),
)

latest_first = Window.partitionBy("order_id").orderBy(F.col("updated_at").desc())

clean = (
    typed
    .withColumn("dq_issues", F.when(dq == "", None).otherwise(dq))
    .withColumn("_rn", F.row_number().over(latest_first))
    .filter("_rn = 1")
    .drop("_rn", "_raw_amount")
    .withColumn("_ingest_date", F.lit(ingest_date))
    .withColumn("_processed_at", F.current_timestamp())
)

# 5. Load: conform to the target schema, then MERGE (upsert)
target = spark.table("glue_catalog.silver.orders")
clean = clean.select([F.col(f.name).cast(f.dataType) for f in target.schema])
print(f"[transform] {clean.count()} clean rows after dedupe")

clean.createOrReplaceTempView("updates")
spark.sql("""
    MERGE INTO glue_catalog.silver.orders AS t
    USING updates AS s
    ON t.order_id = s.order_id
    WHEN MATCHED AND s.updated_at >= t.updated_at THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")

total = spark.table("glue_catalog.silver.orders").count()
print(f"[load] silver.orders now has {total} rows")
