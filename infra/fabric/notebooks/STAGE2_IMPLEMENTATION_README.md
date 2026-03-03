# Stage 2 & 3 Implementation - Brown Shipley

## Overview

This implementation creates the **transformation layer** that bridges Stage 1 raw ingestion and downstream TPIR consumption, replicating the Excel workbook's 3-stage pipeline in Microsoft Fabric.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Stage 1: Raw Ingestion (v2 notebooks)                                   │
│ - nb_ingest_brown_shipley_v2.ipynb                                       │
│ - Preserves all source columns as strings                                │
│ - Output: stage1_brown_shipley_positions_raw, stage1_brown_shipley_cash_raw│
└──────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────┐
│ Stage 2: Transformation & Enrichment (NEW)                               │
│ - nb_stage2_brown_shipley.ipynb                                          │
│ - Policy mapping (client_id → policyholder_number)                       │
│ - Security identifier resolution (SEDOL → ISIN → synthetic cash codes)   │
│ - Asset name enrichment from security master                             │
│ - Include/Remove flagging with exclusion reasons                         │
│ - Holdings check flags for validation                                    │
│ - Decision traceability                                                  │
│ - Output: individual_dfm_consolidated (220 rows, row-for-row with Stage 1)│
└──────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────┐
│ Stage 3: TPIR Projection (NEW)                                           │
│ - nb_stage3_tpir_projection.ipynb                                        │
│ - Filter to Include-only rows                                            │
│ - Project to 13-column TPIR schema                                       │
│ - Output: tpir_load_equivalent (191 rows for Brown Shipley template)     │
└──────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────┐
│ Validation: Data Quality Checks (ENHANCED)                               │
│ - nb_validate_enhanced.ipynb                                             │
│ - DATE_001: Report date timeliness (warning)                             │
│ - MV_001: Market value reconciliation (exception)                        │
│ - VAL_001: Policy value check (exception)                                │
│ - MAP_001: Identifier completeness (exception)                           │
│ - POP_001: Policy mapping check (exception, disabled)                    │
│ - Output: dq_results, dq_exception_rows                                  │
└──────────────────────────────────────────────────────────────────────────┘
```

## Files Created

### Notebooks

1. **`nb_stage2_brown_shipley.ipynb`**
   - **Purpose**: Transform Stage 1 raw data to standardized Stage 2 format
   - **Input**: `stage1_brown_shipley_positions_raw`, `stage1_brown_shipley_cash_raw`
   - **Output**: `individual_dfm_consolidated`
   - **Key Logic**:
     - Combines positions + cash (full outer join on client_id)
     - Joins with policy_mapping (client_id → policyholder_number)
     - Joins with security_master (ISIN/SEDOL enrichment)
     - Applies identifier resolution: SEDOL priority → ISIN fallback → `TPY_CASH_{CURRENCY}`
     - Flags Include/Remove with exclusion_reason_code
     - Adds holdings_check_flag (2% tolerance)
     - Populates decision_trace_json for audit trail
   - **Row Count Contract**: Same as Stage 1 (e.g., 220 in → 220 out)

2. **`nb_stage3_tpir_projection.ipynb`**
   - **Purpose**: Filter Stage 2 to Include-only and project to TPIR schema
   - **Input**: `individual_dfm_consolidated`
   - **Output**: `tpir_load_equivalent`
   - **Key Logic**:
     - Filter `include_flag = 'Include'`
     - Project to 13-column TPIR schema
     - Stub acquisition cost as 0.0 (PoC limitation)
   - **Row Count Contract**: Subset of Stage 2 (e.g., 191 out of 220)
   - **Value Reconciliation**: Stage 2 total - Removed total = TPIR total

3. **`nb_validate_enhanced.ipynb`**
   - **Purpose**: Run all 5 baseline validation checks
   - **Input**: `individual_dfm_consolidated`
   - **Output**: `dq_results`, `dq_exception_rows`
   - **Checks**:
     - **DATE_001** (warning): Report date within 5 working days of month end
     - **MV_001** (exception): Holdings × Price × FX ≈ Bid Value (±£1 or ±0.1%)
     - **VAL_001** (exception): Policy must have cash/stock value (not all zeros)
     - **MAP_001** (exception): Non-cash securities must have identifier
     - **POP_001** (exception, disabled): Policy must map to IH policy ID

### Configuration

4. **`exclusion_policies.csv`**
   - **Purpose**: Define which policies/accounts should be flagged as "Remove"
   - **Location**: `infra/fabric/config/exclusion_policies.csv`
   - **Schema**: `dfm_id`, `policy_id`, `exclusion_reason`, `status`, `effective_from`, `notes`
   - **Usage**: Stage 2 notebook reads this to apply exclusion rules
   - **Current State**: Template with example rows (replace with real exclusion data)

## Execution Flow

### Manual Testing (Brown Shipley)

```bash
# 1. Run Stage 1 v2 ingestion
# → Creates stage1_brown_shipley_positions_raw, stage1_brown_shipley_cash_raw

# 2. Run Stage 2 transformation
# → Reads Stage 1 raw tables
# → Applies mappings, enrichment, exclusion logic
# → Writes individual_dfm_consolidated

# 3. Run Stage 3 projection
# → Reads individual_dfm_consolidated
# → Filters to Include-only
# → Writes tpir_load_equivalent

# 4. Run validation
# → Reads individual_dfm_consolidated
# → Executes 5 checks
# → Writes dq_results and dq_exception_rows

# 5. Review results
# → Check dq_results for pass/fail status
# → Investigate dq_exception_rows for failing rows
```

### Parameters

All notebooks accept standard parameters:
- `period` (string): Format "YYYY-MM", e.g., "2026-03"
- `run_id` (string): Unique run identifier, e.g., "manual_test_run"

### Expected Row Counts (Brown Shipley Template)

Based on Excel workbook reference:
- **Stage 1 raw**: 220 rows (positions + cash combined)
- **Stage 2 consolidated**: 220 rows (row-for-row with Stage 1, enriched)
- **Stage 2 Include**: 191 rows (flagged "Include")
- **Stage 2 Remove**: 29 rows (flagged "Remove")
- **Stage 3 TPIR**: 191 rows (Include subset only)

## Key Design Decisions

### 1. Identifier Resolution Priority
```
1. SEDOL (if available) → security_code = SEDOL, id_type = "SEDOL"
2. ISIN (if SEDOL missing) → security_code = ISIN, id_type = "ISIN"
3. Cash (no SEDOL/ISIN) → security_code = "TPY_CASH_{CURRENCY}", id_type = "Undertaking - Specific"
```

### 2. Include/Remove Logic
- **Remove** if:
  - Zero bid value AND zero cash value
  - Cash line with zero value (currency placeholder)
  - Policy in exclusion_policies table (when implemented)
- **Include** otherwise

### 3. Holdings Check (MV_001)
- Formula: `|holding × price × fx_rate - bid_value_gbp| / bid_value_gbp`
- Tolerance: ±0.1% (configurable via rules_config.json)
- **Note**: Brown Shipley source doesn't have holding/price, so this check will be "not_evaluable"

### 4. Decision Traceability
Every row includes `decision_trace_json` with:
```json
{
  "policy_original": "ID-8E40812F",
  "policy_mapped": "ID-C371162F",
  "policy_mapping_applied": true,
  "identifier_chosen": "SEDOL",
  "source_sedol": "0263494",
  "source_isin": "GB0002634946",
  "security_code": "0263494",
  "exclusion_reason_code": null,
  "holdings_check_flag": "not_evaluable"
}
```

## Reference Data Requirements

### 1. policy_mapping.csv
- **Schema**: `dfm_id`, `dfm_policy_ref`, `ih_policy_ref`, `status`
- **Purpose**: Maps DFM account numbers to IH policy identifiers
- **Example**: `brown_shipley`,`ID-8E40812F`,`ID-C371162F`,`active`

### 2. security_master.csv
- **Schema**: `isin`, `sedol`, `asset_name`, `asset_class`, `currency_iso`
- **Purpose**: Enriches asset names for securities
- **Example**: `GB0002634946`,`0263494`,`BP PLC`,`Equity`,`GBP`

### 3. fx_rates.csv
- **Schema**: `currency`, `rate_to_gbp`
- **Purpose**: Converts local currency values to GBP
- **Example**: `EUR`,`0.85`

### 4. rules_config.json
- **Schema**: JSON with `validation_rules` array
- **Purpose**: Defines validation check parameters (tolerances, thresholds)
- **Example**:
  ```json
  {
    "validation_rules": [
      {
        "rule_id": "MV_001",
        "enabled": true,
        "severity": "exception",
        "tolerance_pct": 0.1,
        "tolerance_abs": 1.0
      }
    ]
  }
  ```

### 5. exclusion_policies.csv (NEW)
- **Schema**: `dfm_id`, `policy_id`, `exclusion_reason`, `status`, `effective_from`, `notes`
- **Purpose**: Defines which policies should be flagged as "Remove"
- **Example**: `brown_shipley`,`ID-CLOSED-001`,`CLOSED_ACCOUNT`,`active`,`2026-01-01`,`Account closed in Jan 2026`

## Data Quality Flags

### Stage 2 Flags (data_quality_flags array)
- `FX_NOT_AVAILABLE`: No FX rate found for currency
- `POLICY_NOT_MAPPED`: client_id not found in policy_mapping
- `MV_NOT_EVALUABLE`: Cannot calculate holdings check (missing holding/price)

### Validation Checks (dq_results)
Each check writes:
- `check_id`: Rule identifier (e.g., "MV_001")
- `severity`: "warning" or "exception"
- `status`: "pass" or "fail"
- `metric_value`: Count of failures
- `threshold`: Configured tolerance
- `details_json`: Additional context (DFM breakdown, etc.)

### Exception Rows (dq_exception_rows)
Failing rows include:
- `check_id`: Rule that failed
- `dfm_id`: DFM identifier
- `source_file`: Original source file name
- `source_row_id`: Row identifier for traceability
- `failure_reason`: Human-readable explanation

## Testing Checklist

### Stage 2 Validation
- [ ] Row count preserved: Stage 1 count == Stage 2 count
- [ ] All policies mapped: Check `policy_mapping_applied` flag distribution
- [ ] All securities have identifiers: Check `identifier_chosen` distribution
- [ ] Include/Remove flagged correctly: 191 Include, 29 Remove (Brown Shipley template)
- [ ] Decision trace populated: All rows have `decision_trace_json`

### Stage 3 Validation
- [ ] Include-only filter: Stage 3 count == Stage 2 Include count
- [ ] Value reconciliation: Stage 2 total - Removed total = Stage 3 total (within FX tolerance)
- [ ] TPIR schema complete: All 13 columns populated

### Validation Check Outcomes
- [ ] DATE_001 executed: Check for late report dates
- [ ] MV_001 executed: Identify holdings/value mismatches (if evaluable)
- [ ] VAL_001 executed: Identify zero-value policies
- [ ] MAP_001 executed: Identify missing identifiers (non-cash only)
- [ ] POP_001 skipped: Disabled by default
- [ ] dq_results table has entries for each check
- [ ] dq_exception_rows table has failing rows (if any)

## Known Limitations (PoC)

1. **Acquisition Cost**: Stubbed as 0.0 in TPIR output (not available in source)
2. **Holdings × Price Check**: Brown Shipley source doesn't provide holding/price, so MV_001 will be "not_evaluable"
3. **Working Days Calculation**: DATE_001 uses approximate +7 calendar days instead of precise 5 working days
4. **Exclusion Policies**: Template only - needs real data from business
5. **Security Master Coverage**: May not have all securities - asset name will fallback to source instrument name

## Next Steps

### Immediate (PoC Completion)
1. **Test Brown Shipley end-to-end**: Run Stage 1 → Stage 2 → Stage 3 → Validation
2. **Verify row counts**: Confirm 220 → 220 → 191 pattern
3. **Review validation results**: Check dq_results and dq_exception_rows
4. **Validate totals reconciliation**: Stage 2 - Removed = TPIR (within tolerance)

### Short-term (Replicate to Other DFMs)
1. Create `nb_stage2_pershing.ipynb` (adapt to multiple CSV types)
2. Create `nb_stage2_castlebay.ipynb` (adapt to Excel multi-sheet)
3. Create `nb_stage2_wh_ireland.ipynb` (reference: test_stage2_bridge_ireland.py)
4. Update `nb_stage3_tpir_projection.ipynb` to handle all DFMs (already generic)
5. Update `nb_validate_enhanced.ipynb` to handle all DFMs (already generic)

### Medium-term (Production Readiness)
1. **Populate Reference Data**:
   - Complete policy_mapping.csv with real mappings
   - Populate exclusion_policies.csv with real exclusions
   - Expand security_master.csv coverage
2. **Orchestration**: Create `nb_run_stage2_all.ipynb` to run all DFMs in sequence
3. **Monitoring**: Add Fabric alerts for validation failures
4. **Documentation**: Create runbooks for Stage 2 troubleshooting
5. **Performance**: Optimize joins and aggregations for large datasets

### Long-term (Enhancement)
1. **Acquisition Cost**: Integrate with external data source
2. **Holdings/Price**: Source from market data provider for MV_001 check
3. **Precise Working Days**: Implement business calendar for DATE_001
4. **Movement Checks**: Compare period-over-period for anomalies
5. **IH Coverage Check**: Enable POP_001 once policy mapping complete

## Support

For issues or questions:
1. Check `dq_exception_rows` for failing row details
2. Review `decision_trace_json` for transformation decisions
3. Validate reference data (policy_mapping, security_master, fx_rates)
4. Confirm Stage 1 raw tables have data for period/run_id
5. Check Fabric logs for notebook execution errors

---

**Created**: 2026-03-03
**Author**: Copilot Agent
**Version**: 1.0 (PoC - Brown Shipley)
