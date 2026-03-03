# =========================
# test_stage2_bridge_ireland.py
# Manual Stage 2 Bridge Test for WH Ireland
# =========================
# Run this to verify Stage 2 bridge is working correctly

from pyspark.sql import functions as F
from datetime import datetime, timezone

period = "2026-03"
run_id = "manual_test_run"
dfm_id = "wh_ireland"

print(f"\n{'='*70}")
print(f"STAGE 2 BRIDGE TEST - WH Ireland")
print(f"Period: {period}, Run ID: {run_id}")
print(f"{'='*70}\n")

# ========== CHECK 1: Canonical Holdings ==========
print("[1] Canonical Holdings (Legacy Source)")
print("-" * 70)

canonical = spark.table("canonical_holdings").filter(
    (F.col("period") == period) & (F.col("run_id") == run_id) & (F.col("dfm_id") == dfm_id)
)

canonical_count = canonical.count()
print(f"Total rows: {canonical_count}")

# Show distribution by ISIN status
isin_stats = canonical.select(
    F.when(F.col("isin").isNull(), "CASH (no ISIN)").otherwise("SECURITY (has ISIN)").alias("type"),
    F.count("*").alias("count")
).groupBy("type").agg(F.sum("count").alias("count")).orderBy("type")

print(f"\nDistribution:")
for row in isin_stats.collect():
    print(f"  {row['type']}: {row['count']} rows")

# Sample a cash row
print(f"\nSample CASH row (ISIN is null):")
cash_sample = canonical.filter(F.col("isin").isNull()).limit(1)
if not cash_sample.rdd.isEmpty():
    for row in cash_sample.select("policy_id", "security_id", "isin", "holding", "local_currency", "bid_value_gbp").collect():
        print(f"  policy_id: {row['policy_id']}")
        print(f"  security_id: {row['security_id']}")
        print(f"  isin: {row['isin']}")
        print(f"  holding: {row['holding']}")
        print(f"  local_currency: {row['local_currency']}")
        print(f"  bid_value_gbp: {row['bid_value_gbp']}")

# Sample a security row
print(f"\nSample SECURITY row (has ISIN):")
sec_sample = canonical.filter(F.col("isin").isNotNull()).limit(1)
if not sec_sample.rdd.isEmpty():
    for row in sec_sample.select("policy_id", "security_id", "isin", "holding", "local_currency", "bid_value_gbp").collect():
        print(f"  policy_id: {row['policy_id']}")
        print(f"  security_id: {row['security_id']}")
        print(f"  isin: {row['isin']}")
        print(f"  holding: {row['holding']}")
        print(f"  local_currency: {row['local_currency']}")
        print(f"  bid_value_gbp: {row['bid_value_gbp']}")

# ========== CHECK 2: Run Bridge ==========
print(f"\n[2] Running Stage 2 Bridge Function")
print("-" * 70)

def table_exists(table_name: str) -> bool:
    try:
        return spark.catalog.tableExists(table_name)
    except Exception:
        return False

if not table_exists("canonical_holdings"):
    print("ERROR: canonical_holdings table not found")
    mssparkutils.notebook.exit("FAILED")

source_df = spark.table("canonical_holdings").filter(
    (F.col("period") == period) & (F.col("run_id") == run_id)
)

# Cash mapping logic
enriched = (
    source_df
    .withColumn(
        "_is_cash",
        F.col("isin").isNull() & F.col("security_id").isNull()
    )
    .withColumn(
        "security_code_out",
        F.when(
            F.col("_is_cash"),
            F.concat_ws("_", F.lit("TPY_CASH"), F.upper(F.coalesce(F.col("local_currency"), F.lit("XX"))))
        ).otherwise(F.col("security_id"))
    )
    .withColumn(
        "id_type_out",
        F.when(F.col("_is_cash"), F.lit("Undertaking - Specific"))
         .otherwise(F.col("id_type"))
    )
    .withColumn(
        "asset_name_out",
        F.when(F.col("_is_cash"), F.lit("CASH"))
         .otherwise(F.col("asset_name"))
    )
)

stage2_test = (
    enriched
    .withColumn("profile_id", F.col("dfm_id"))
    .withColumn("row_hash", F.sha2(F.concat_ws("|", F.col("run_id"), F.col("dfm_id"), F.col("source_row_id")), 256))
    .withColumn("policyholder_number", F.col("policy_id"))
    .withColumn("security_code", F.col("security_code_out"))
    .withColumn("sedol", F.lit(None).cast("string"))
    .withColumn("include_flag", F.lit("Include"))
    .withColumn("exclusion_reason_code", F.lit(None).cast("string"))
    .withColumn("identifier_chosen", F.coalesce(F.col("security_code_out"), F.col("isin")))
    .withColumn(
        "decision_trace_json",
        F.to_json(
            F.struct(
                F.lit("bridge_from_canonical_holdings").alias("strategy"),
                F.col("dfm_id").alias("dfm_id"),
                F.col("_is_cash").alias("cash_mapping_applied"),
                F.current_timestamp().alias("bridged_at")
            )
        )
    )
)

print(f"Bridge transformation created: {stage2_test.count()} rows")

# ========== CHECK 3: Verify Cash Mapping ==========
print(f"\n[3] Cash Mapping Verification")
print("-" * 70)

# Count cash rows
cash_rows = stage2_test.filter(F.col("id_type") == "Undertaking - Specific").count()
sec_rows = stage2_test.filter(F.col("id_type") != "Undertaking - Specific").count()

print(f"Mapped cash rows (id_type='Undertaking - Specific'): {cash_rows}")
print(f"Security rows (id_type != 'Undertaking - Specific'): {sec_rows}")

print(f"\nCash security codes generated:")
cash_codes = stage2_test.filter(F.col("id_type") == "Undertaking - Specific").select("security_code").distinct().collect()
for i, row in enumerate(cash_codes, 1):
    print(f"  {i}. {row['security_code']}")

# Sample a transformed cash row
print(f"\nSample transformed CASH row:")
cash_transformed = stage2_test.filter(F.col("id_type") == "Undertaking - Specific").limit(1)
if not cash_transformed.rdd.isEmpty():
    for row in cash_transformed.select(
        "policyholder_number", "security_code", "isin", "id_type", "asset_name", "include_flag"
    ).collect():
        print(f"  policyholder_number: {row['policyholder_number']}")
        print(f"  security_code: {row['security_code']}")
        print(f"  isin: {row['isin']}")
        print(f"  id_type: {row['id_type']}")
        print(f"  asset_name: {row['asset_name']}")
        print(f"  include_flag: {row['include_flag']}")

# Sample a transformed security row
print(f"\nSample transformed SECURITY row:")
sec_transformed = stage2_test.filter(F.col("id_type") != "Undertaking - Specific").limit(1)
if not sec_transformed.rdd.isEmpty():
    for row in sec_transformed.select(
        "policyholder_number", "security_code", "isin", "id_type", "asset_name", "include_flag"
    ).collect():
        print(f"  policyholder_number: {row['policyholder_number']}")
        print(f"  security_code: {row['security_code']}")
        print(f"  isin: {row['isin']}")
        print(f"  id_type: {row['id_type']}")
        print(f"  asset_name: {row['asset_name']}")
        print(f"  include_flag: {row['include_flag']}")

# ========== CHECK 4: Validation ==========
print(f"\n[4] Validation Summary")
print("-" * 70)

validations = {
    "✓ Canonical has 220 rows": canonical_count == 220,
    "✓ Cash rows detected (25 expected)": cash_rows == 25,
    "✓ Security rows present (195 expected)": sec_rows == 195,
    "✓ All rows have include_flag='Include'": stage2_test.filter(F.col("include_flag") != "Include").count() == 0,
    "✓ Cash rows have TPY_CASH_* security_code": stage2_test.filter(
        (F.col("id_type") == "Undertaking - Specific") & ~F.col("security_code").startswith("TPY_CASH")
    ).count() == 0,
    "✓ Cash rows have asset_name='CASH'": stage2_test.filter(
        (F.col("id_type") == "Undertaking - Specific") & (F.col("asset_name") != "CASH")
    ).count() == 0,
}

passed = sum(1 for v in validations.values() if v)
total = len(validations)

for check, result in validations.items():
    status = "PASS" if result else "FAIL"
    print(f"  {check:<50} {status}")

print(f"\n{'='*70}")
print(f"Result: {passed}/{total} validations passed")
if passed == total:
    print("STATUS: ✓ Stage 2 bridge is working correctly!")
else:
    print("STATUS: ✗ Review failed checks above")
print(f"{'='*70}\n")

mssparkutils.notebook.exit("VALIDATION_COMPLETE")
