-- ============================================================
-- STEP 1: Run this SQL in Fabric SQL Notebook Cell
-- ============================================================

-- Create the Reconciliation Validation View
CREATE OR REPLACE VIEW vw_holdings_price_validation AS
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
    -- Identification
    source_row_id,
    policyholder_number,
    security_code,
    asset_name,

    -- Lookup context
    currency_code,
    include_flag,

    -- Core metrics
    holding,
    local_bid_price,
    bid_value_local,
    bid_value_gbp,

    -- Reconciliation calculation
    CASE
        WHEN holding IS NULL OR local_bid_price IS NULL OR bid_value_local IS NULL THEN NULL
        WHEN bid_value_local = 0 THEN NULL
        ELSE ROUND((CAST(holding AS DOUBLE) * CAST(local_bid_price AS DOUBLE)) / bid_value_local * 100.0, 2)
    END AS reconciliation_pct,

    -- Outlier flag (outside 98-102% range)
    CASE
        WHEN holding IS NULL OR local_bid_price IS NULL OR bid_value_local IS NULL THEN 'MISSING_DATA'
        WHEN bid_value_local = 0 THEN 'ZERO_VALUE'
        WHEN (CAST(holding AS DOUBLE) * CAST(local_bid_price AS DOUBLE)) / bid_value_local * 100.0 < 98.0 THEN 'BELOW_RANGE'
        WHEN (CAST(holding AS DOUBLE) * CAST(local_bid_price AS DOUBLE)) / bid_value_local * 100.0 > 102.0 THEN 'ABOVE_RANGE'
        ELSE 'IN_RANGE'
    END AS reconciliation_status,

    -- Variance from expected (100%)
    CASE
        WHEN holding IS NULL OR local_bid_price IS NULL OR bid_value_local IS NULL THEN NULL
        WHEN bid_value_local = 0 THEN NULL
        ELSE ROUND(((CAST(holding AS DOUBLE) * CAST(local_bid_price AS DOUBLE)) / bid_value_local * 100.0) - 100.0, 2)
    END AS variance_from_100_pct,

    -- Data completeness flags
    CASE WHEN holding IS NULL THEN 1 ELSE 0 END AS is_holding_null,
    CASE WHEN local_bid_price IS NULL THEN 1 ELSE 0 END AS is_price_null,
    CASE WHEN bid_value_local IS NULL THEN 1 ELSE 0 END AS is_bid_value_null,

    -- Metadata
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

-- Verify view was created
SELECT COUNT(*) as record_count FROM vw_holdings_price_validation;

-- ============================================================
-- STEP 2: Preview the reconciliation metrics (first 1000 rows)
-- ============================================================

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
FROM vw_holdings_price_validation
ORDER BY ABS(variance_from_100_pct) DESC
LIMIT 1000;

-- ============================================================
-- STEP 3: Check reconciliation summary statistics
-- ============================================================

SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) AS records_in_range,
    SUM(CASE WHEN reconciliation_status != 'IN_RANGE' THEN 1 ELSE 0 END) AS outlier_records,
    ROUND(100.0 * SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_in_range,
    MIN(reconciliation_pct) AS min_reconciliation_pct,
    MAX(reconciliation_pct) AS max_reconciliation_pct,
    ROUND(AVG(reconciliation_pct), 2) AS avg_reconciliation_pct
FROM vw_holdings_price_validation;

-- ============================================================
-- STEP 4: Breakdown by reconciliation status
-- ============================================================

SELECT 
    reconciliation_status,
    COUNT(*) AS record_count,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM vw_holdings_price_validation) AS pct_of_total
FROM vw_holdings_price_validation
GROUP BY reconciliation_status
ORDER BY record_count DESC;

-- ============================================================
-- STEP 5: Top 20 outliers (greatest variance)
-- ============================================================

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
FROM vw_holdings_price_validation
WHERE reconciliation_status != 'IN_RANGE'
ORDER BY ABS(variance_from_100_pct) DESC
LIMIT 20;

-- ============================================================
-- STEP 6: Breakdown by currency
-- ============================================================

SELECT
    currency_code,
    COUNT(*) AS record_count,
    SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) AS in_range_count,
    ROUND(100.0 * SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_in_range,
    MIN(reconciliation_pct) AS min_pct,
    MAX(reconciliation_pct) AS max_pct,
    ROUND(AVG(reconciliation_pct), 2) AS avg_pct
FROM vw_holdings_price_validation
GROUP BY currency_code
ORDER BY record_count DESC;

-- ============================================================
-- STEP 7: Breakdown by include/exclude flag
-- ============================================================

SELECT
    include_flag,
    COUNT(*) AS record_count,
    SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) AS in_range_count,
    ROUND(100.0 * SUM(CASE WHEN reconciliation_status = 'IN_RANGE' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_in_range
FROM vw_holdings_price_validation
GROUP BY include_flag
ORDER BY include_flag;
