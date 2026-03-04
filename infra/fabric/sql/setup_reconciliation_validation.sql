-- ============================================================
-- Reconciliation Validation Setup (Fabric Spark SQL)
-- Creates BOTH a physical table and a view so they are easy to find
-- in OneLake Catalog / Power BI navigator.
-- ============================================================

-- 0) Context checks
SELECT current_database() AS active_database;
SELECT COUNT(*) AS source_row_count FROM individual_dfm_consolidated;

-- 1) Remove prior objects (safe idempotent)
DROP VIEW IF EXISTS vw_holdings_price_validation;
DROP TABLE IF EXISTS holdings_price_validation;

-- 2) Create physical Delta table for reliable catalog visibility
CREATE TABLE holdings_price_validation
USING DELTA
AS
WITH base AS (
    SELECT
        source_row_id,
        policyholder_number,
        security_code,
        asset_name,
        local_currency AS currency_code,
        include_flag,
        holding,
        local_bid_price,
        bid_value_gbp,
        CASE
            WHEN bid_value_gbp IS NULL OR fx_rate IS NULL OR fx_rate = 0 THEN NULL
            ELSE CAST(bid_value_gbp AS DOUBLE) / CAST(fx_rate AS DOUBLE)
        END AS bid_value_local,
        period,
        run_id,
        id_type,
        isin,
        sedol,
        other_security_id,
        accrued_interest_gbp,
        cash_value_gbp,
        fx_rate,
        exclusion_reason_code,
        identifier_chosen
    FROM individual_dfm_consolidated
    WHERE security_code IS NOT NULL
      AND TRIM(security_code) != ''
)
SELECT
    source_row_id,
    policyholder_number,
    security_code,
    asset_name,
    currency_code,
    include_flag,
    holding,
    local_bid_price,
    bid_value_local,
    bid_value_gbp,
    CASE
        WHEN holding IS NULL OR local_bid_price IS NULL OR bid_value_local IS NULL THEN NULL
        WHEN bid_value_local = 0 THEN NULL
        ELSE ROUND((CAST(holding AS DOUBLE) * CAST(local_bid_price AS DOUBLE)) / bid_value_local * 100.0, 2)
    END AS reconciliation_pct,
    CASE
        WHEN holding IS NULL OR local_bid_price IS NULL OR bid_value_local IS NULL THEN 'MISSING_DATA'
        WHEN bid_value_local = 0 THEN 'ZERO_VALUE'
        WHEN (CAST(holding AS DOUBLE) * CAST(local_bid_price AS DOUBLE)) / bid_value_local * 100.0 < 98.0 THEN 'BELOW_RANGE'
        WHEN (CAST(holding AS DOUBLE) * CAST(local_bid_price AS DOUBLE)) / bid_value_local * 100.0 > 102.0 THEN 'ABOVE_RANGE'
        ELSE 'IN_RANGE'
    END AS reconciliation_status,
    CASE
        WHEN holding IS NULL OR local_bid_price IS NULL OR bid_value_local IS NULL THEN NULL
        WHEN bid_value_local = 0 THEN NULL
        ELSE ROUND(((CAST(holding AS DOUBLE) * CAST(local_bid_price AS DOUBLE)) / bid_value_local * 100.0) - 100.0, 2)
    END AS variance_from_100_pct,
    CASE WHEN holding IS NULL THEN 1 ELSE 0 END AS is_holding_null,
    CASE WHEN local_bid_price IS NULL THEN 1 ELSE 0 END AS is_price_null,
    CASE WHEN bid_value_local IS NULL THEN 1 ELSE 0 END AS is_bid_value_null,
    period,
    run_id,
    id_type,
    isin,
    sedol,
    other_security_id,
    accrued_interest_gbp,
    cash_value_gbp,
    fx_rate,
    exclusion_reason_code,
    identifier_chosen,
    current_timestamp() AS view_refresh_time
FROM base;

-- 3) Create a companion view (some tools prefer views)
CREATE VIEW vw_holdings_price_validation AS
SELECT *
FROM holdings_price_validation;

-- 4) Discovery checks (these prove object creation in current context)
SHOW TABLES LIKE 'holdings_price_validation';
SHOW TABLES LIKE 'vw_holdings_price_validation';

SELECT COUNT(*) AS validation_row_count
FROM holdings_price_validation;

-- 5) Quick preview
SELECT
    policyholder_number,
    security_code,
    asset_name,
    holding,
    local_bid_price,
    bid_value_local,
    reconciliation_pct,
    reconciliation_status,
    variance_from_100_pct,
    currency_code,
    include_flag
FROM holdings_price_validation
ORDER BY ABS(variance_from_100_pct) DESC
LIMIT 1000;

-- 6) Summary stats
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) AS records_in_range,
    SUM(CASE WHEN reconciliation_status != 'IN_RANGE' THEN 1 ELSE 0 END) AS outlier_records,
    ROUND(100.0 * SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_in_range,
    MIN(reconciliation_pct) AS min_reconciliation_pct,
    MAX(reconciliation_pct) AS max_reconciliation_pct,
    ROUND(AVG(reconciliation_pct), 2) AS avg_reconciliation_pct
FROM holdings_price_validation;

-- 7) Breakdown by status
SELECT
    reconciliation_status,
    COUNT(*) AS record_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM holdings_price_validation), 2) AS pct_of_total
FROM holdings_price_validation
GROUP BY reconciliation_status
ORDER BY record_count DESC;

-- 8) Top 20 outliers
SELECT
    policyholder_number,
    security_code,
    asset_name,
    holding,
    local_bid_price,
    bid_value_local,
    reconciliation_pct,
    variance_from_100_pct,
    currency_code,
    include_flag,
    isin,
    sedol
FROM holdings_price_validation
WHERE reconciliation_status != 'IN_RANGE'
ORDER BY ABS(variance_from_100_pct) DESC
LIMIT 20;

-- 9) Breakdown by currency
SELECT
    currency_code,
    COUNT(*) AS record_count,
    SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) AS in_range_count,
    ROUND(100.0 * SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_in_range,
    MIN(reconciliation_pct) AS min_pct,
    MAX(reconciliation_pct) AS max_pct,
    ROUND(AVG(reconciliation_pct), 2) AS avg_pct
FROM holdings_price_validation
GROUP BY currency_code
ORDER BY record_count DESC;

-- 10) Breakdown by include/exclude
SELECT
    include_flag,
    COUNT(*) AS record_count,
    SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) AS in_range_count,
    ROUND(100.0 * SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_in_range
FROM holdings_price_validation
GROUP BY include_flag
ORDER BY include_flag;
