-- ============================================================
-- View: vw_holdings_price_validation
-- Purpose: Reconciliation check for holdings * price (bid) metric
-- Business Rule: holdings * bid_price should be within 98-102% 
--                of calculated bid_value_local (holding * local_bid_price)
-- ============================================================

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
