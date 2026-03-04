# Power BI Report: Holdings*Price Reconciliation Validator

## Setup Instructions

### 1. Create Fabric SQL View (Prerequisites)

Run the following SQL in a Fabric SQL notebook cell:

```sql
-- ============================================================
-- View: vw_holdings_price_validation
-- Purpose: Reconciliation check for holdings * price (bid) metric
-- Business Rule: holdings * bid_price should be within 98-102% 
--                of bid_value_local to catch data quality issues
-- ============================================================

CREATE OR REPLACE VIEW vw_holdings_price_validation AS
SELECT 
    -- Identification
    client_id,
    security_code,
    instrument_name,
    source_row_id,
    source_record_type,
    
    -- Lookup context
    currency_code,
    include_exclude,
    
    -- Core metrics
    holding,
    local_bid_price,
    bid_value_local,
    bid_value_gbp,
    
    -- Reconciliation calculation
    CASE 
        WHEN holding IS NULL OR local_bid_price IS NULL OR bid_value_local IS NULL 
        THEN NULL
        WHEN bid_value_local = 0 
        THEN NULL
        ELSE ROUND((holding * local_bid_price) / bid_value_local * 100.0, 2)
    END AS reconciliation_pct,
    
    -- Outlier flag (outside 98-102% range)
    CASE 
        WHEN holding IS NULL OR local_bid_price IS NULL OR bid_value_local IS NULL 
        THEN 'MISSING_DATA'
        WHEN bid_value_local = 0 
        THEN 'ZERO_VALUE'
        WHEN (holding * local_bid_price) / bid_value_local * 100.0 < 98.0 
        THEN 'BELOW_RANGE'
        WHEN (holding * local_bid_price) / bid_value_local * 100.0 > 102.0 
        THEN 'ABOVE_RANGE'
        ELSE 'IN_RANGE'
    END AS reconciliation_status,
    
    -- Variance from expected (100%)
    CASE 
        WHEN holding IS NULL OR local_bid_price IS NULL OR bid_value_local IS NULL 
        THEN NULL
        WHEN bid_value_local = 0 
        THEN NULL
        ELSE ROUND(((holding * local_bid_price) / bid_value_local * 100.0) - 100.0, 2)
    END AS variance_from_100_pct,
    
    -- Data completeness flags
    CASE WHEN holding IS NULL THEN 1 ELSE 0 END AS is_holding_null,
    CASE WHEN local_bid_price IS NULL THEN 1 ELSE 0 END AS is_price_null,
    CASE WHEN bid_value_local IS NULL THEN 1 ELSE 0 END AS is_bid_value_null,
    
    -- Metadata
    period,
    run_id,
    current_timestamp() AS view_refresh_time
    
FROM individual_dfm_consolidated
WHERE 1=1
    -- Exclude null security codes
    AND security_code IS NOT NULL
    AND TRIM(security_code) != ''
;
```

### 2. Power BI Report Structure

Create a Power BI report with the following pages:

#### **Page 1: Reconciliation Summary Dashboard**
- **KPI Cards**:
  - Total Holdings Records: `COUNTROWS(vw_holdings_price_validation)`
  - Records In Range (98-102%): Count where `reconciliation_status = 'IN_RANGE'`
  - Outlier Count: Count where `reconciliation_status != 'IN_RANGE'`
  - Outlier %: `[Outlier Count] / [Total Records]`

- **Reconciliation Distribution (Histogram)**
  - X-axis: `reconciliation_pct` (binned by 1% buckets: 94-96, 96-98, 98-100, 100-102, 102-104, 104+)
  - Y-axis: Count of records
  - Color: `reconciliation_status` (IN_RANGE=Green, BELOW_RANGE=Red, ABOVE_RANGE=Orange, MISSING_DATA=Gray)

- **Top Issues Table** (Top 20 records by absolute variance)
  - Columns: `security_code`, `holding`, `local_bid_price`, `bid_value_local`, `reconciliation_pct`, `variance_from_100_pct`, `currency_code`
  - Sort by: `ABS(variance_from_100_pct)` descending
  - Conditional formatting: Red background for variance > ±2, Orange for ±1-2

#### **Page 2: Outlier Analysis & Remediation**
- **Outlier Filter Bar**
  - Filters: `reconciliation_status`, `currency_code`, `include_exclude`, `source_record_type`
  - Date range: `period` (2026-03, etc.)

- **Detailed Outlier Table**
  - Columns: `client_id`, `security_code`, `instrument_name`, `holding`, `local_bid_price`, `bid_value_local`, `reconciliation_pct`, `variance_from_100_pct`, `include_exclude`, `currency_code`
  - Row count indicator showing filtered record count
  - Export button to CSV for remediation team

- **Variance Distribution by Currency**
  - Clustered bar chart
  - X-axis: `currency_code`
  - Y-axis (Left): Count of records
  - Y-axis (Right): Average variance %
  - Segmented by `reconciliation_status`

#### **Page 3: Data Quality Assessment**
- **Data Completeness Scorecard**
  - Non-null Holdings %: `(COUNTROWS() - SUM(is_holding_null)) / COUNTROWS()`
  - Non-null Local Bid Price %: `(COUNTROWS() - SUM(is_price_null)) / COUNTROWS()`
  - Non-null Bid Value Local %: `(COUNTROWS() - SUM(is_bid_value_null)) / COUNTROWS()`

- **Record Type Distribution (Pie Chart)**
  - Segments: `source_record_type` (POSITION, CASH)
  - Color: distinct colors per type

- **Include/Exclude Distribution (Donut Chart)**
  - Segments: `include_exclude` 
  - Tooltip shows reconciliation status breakdown

- **Reconciliation Status Breakdown (Stacked Bar)**
  - X-axis: `source_record_type`
  - Y-axis: Stacked count by `reconciliation_status`
  - Shows data quality by position vs cash

### 3. Connection Details

**Data Source**: Fabric SQL Database
- **Database**: Your default Fabric lakehouse database
- **View**: `vw_holdings_price_validation`
- **Refresh**: Set to hourly auto-refresh or on-demand

### 4. Power Query M Code (for manual setup)

```m
let
    Source = Sql.Database(
        "your-fabric-workspace.analysis.windows.net",
        "default_database"
    ),
    ValidationsView = Source{[Schema="dbo", Item="vw_holdings_price_validation"]}[Data],
    #"Changed Type" = Table.TransformColumnTypes(ValidationsView, {
        {"client_id", type text},
        {"security_code", type text},
        {"holding", type number},
        {"local_bid_price", type number},
        {"bid_value_local", type number},
        {"reconciliation_pct", type number},
        {"variance_from_100_pct", type number},
        {"reconciliation_status", type text}
    })
in
    #"Changed Type"
```

### 5. DAX Measures (Copy into your model)

```dax
-- Total Records
Total Records = COUNTROWS('vw_holdings_price_validation')

-- In Range Count
Records In Range = CALCULATE(
    COUNTROWS('vw_holdings_price_validation'),
    'vw_holdings_price_validation'[reconciliation_status] = "IN_RANGE"
)

-- Outlier Count
Outlier Count = CALCULATE(
    COUNTROWS('vw_holdings_price_validation'),
    'vw_holdings_price_validation'[reconciliation_status] <> "IN_RANGE"
)

-- Outlier Percentage
Outlier % = DIVIDE(
    [Outlier Count],
    [Total Records],
    0
)

-- Average Reconciliation %
Avg Reconciliation % = AVERAGE('vw_holdings_price_validation'[reconciliation_pct])

-- Max Variance
Max Variance = MAXX(
    'vw_holdings_price_validation',
    ABS('vw_holdings_price_validation'[variance_from_100_pct])
)
```

### 6. Workflow Integration

**When to Run**:
1. ✅ Complete Stage 2 notebook execution
2. ✅ Run the Fabric SQL view creation (above)
3. ✅ Open Power BI Desktop and create report
4. ✅ Connect to `vw_holdings_price_validation`
5. ✅ Share report in Fabric workspace for business review
6. 🔍 **Business reviews outliers** (human-in-the-loop)
7. 🔧 **Remediation team updates source data** in Excel/system
8. 🔄 Re-run Stage 2 with corrected data
9. ✅ Proceed to Stage 3 once reconciliation meets tolerance

### 7. Recommended Thresholds

- **Green (In Range)**: 98.0% - 102.0%
- **Yellow (Minor Variance)**: 95.0% - 98.0% or 102.0% - 105.0%
- **Red (Investigate)**: < 95.0% or > 105.0%
- **Gray (Missing Data)**: NULL values or incomplete records

---

## Questions for Business Review

When sharing this report, ask stakeholders:
1. **Are outliers legitimate?** (E.g., intentional rounding in source system)
2. **Which records need remediation?** Flag for re-processing
3. **Are there patterns?** (E.g., specific securities, currencies, or DFMs with consistent issues)
4. **Data quality rules** - Should we tighten tolerance beyond 98-102%?

---

## Next Steps After Validation

Once the business approves the Stage 2 data:
- [ ] Clear Stage 2 and Stage 3 tables
- [ ] Re-run Stage 2 notebook with validated data
- [ ] Re-run Stage 3 notebook (TPIR projection)
- [ ] Export final TPIR dataset for downstream systems
