# Stage 2 Calculated Fields Reference

**Purpose**: Document all derived/calculated columns in `nb_stage2_brown_shipley.ipynb` showing source, calculation, and purpose.

## Step 2: Combine Positions + Cash

| Column | Source | Calculation | Purpose |
|--------|--------|-------------|---------|
| `period` | positions/cash | `COALESCE(pos.period, cash.period)` | Period identifier (e.g., "2026-03") |
| `run_id` | positions/cash | `COALESCE(pos.run_id, cash.run_id)` | Run identifier for traceability |
| `dfm_id` | positions/cash | `COALESCE(pos.dfm_id, cash.dfm_id)` | Data Fund Manager identifier |
| `source_file` | positions/cash | `COALESCE(pos.source_file, cash.source_file)` | Source file name/path |
| `source_row_id` | positions/cash | `COALESCE(pos.source_row_id, cash.source_row_id)` | Row ID in source system |
| `client_id` | positions/cash | `COALESCE(pos.client_id, cash.client_id)` | Policy reference (UBS Ref) - used for lookup |
| `value_date` | positions/cash | `COALESCE(pos.value_date, cash.value_date)` | Reporting date |
| `isin` | positions only | `pos.isin_code` | International Securities Identification Number |
| `sedol` | positions only | `pos.sedol_code` | Stock Exchange Daily Official List code |
| `instrument_name` | positions only | `pos.description_of_security` | Security name/description |
| `instrument_type` | positions only | `pos.type_of_financial_instrument` | Security type classification |
| `balance_local` | positions only | `pos.balance` | Position balance in local currency (string) |
| `accrued_interest_local` | positions only | `pos.accrued_interest` | Accrued interest in local currency (string) |
| `position_currency` | positions only | `pos.currency_code` | Currency of position |
| `cash_balance_local` | cash only | `cash.accounting_balance` | Cash balance in local currency (string) |
| `cash_currency` | cash only | `cash.account_currency` | Currency of cash account |
| `movt_raw` | positions/cash (optional) | `COALESCE(pos.movt, cash.movt)` OR `NULL` | Movement % field (used for tolerance check) |

---

## Step 4: Policy Mapping (Mappings Lookup + IH Report)

| Column | Source | Calculation | Purpose |
|--------|--------|-------------|---------|
| `policyholder_number` | Mappings.xlsx | `JOIN(mappings_raw ON client_id = UBS Ref) → SL PolNo` OR `COALESCE(mapped_value, client_id)` | Mapped policy reference (SL PolNo from Mappings) |
| `policy_mapping_applied` | Mappings.xlsx | `IS NOT NULL(policyholder_number after join)` | Flag: was a mapping found? |
| `ih_lookup_count` | IH Report | `COUNT(*) WHERE policy_number = policyholder_number` | How many times does this policy appear in IH Report? |
| `ih_exclude_flag` | IH Report | `MAX(CASE WHEN status = "EXCLUDE" THEN 1 ELSE 0 END) = 1` | Does IH Report have EXCLUDE status for this policy? |
| `ih_status_raw` | IH Report | `FIRST(status)` if exists, ELSE NULL | Raw status value from IH Report (NOT USED in POC) |
| `ih_policy_exists` | IH Report | `ih_lookup_count > 0` | Boolean: is policy in IH Report? |

**Note**: For POC, `ih_exclude_flag` is not used in Include/Remove logic (workbook would check it, but IH Report only has 2 columns: policy_number, valuation).

---

## Step 5: Security Identifier Resolution & Mapping

| Column | Source | Calculation | Purpose |
|--------|--------|-------------|---------|
| `_is_cash_line` | sedol, isin | `sedol IS NULL AND isin IS NULL` | Boolean: is this a pure cash position? |
| `derived_security_id` | sedol/isin/cash | Priority: `COALESCE(sedol, isin, IF(_is_cash_line, CONCAT("CASH_", UPPER(position_currency)), NULL))` | Selected security identifier (SEDOL → ISIN → synthetic CASH_XXX) |
| `security_code` | Mappings.xlsx | `JOIN(mappings_raw ON (identifier+currency) composite key) → final_security_code/unique_security_code` OR `derived_security_id` | Mapped security code (final/unique code from Mappings) |
| `local_currency` | position_currency | `ALIAS: position_currency` | Currency of position (used downstream) |
| `identifier_chosen` | derived_security_id | `ALIAS: derived_security_id` | Which identifier was selected (SEDOL/ISIN/CASH_XXX) |
| `asset_name` | instrument_name | `ALIAS: instrument_name` | Asset description (for non-cash lines) |
| `id_type` | literal | `LITERAL: "sedol_isin"` | Classification of identifier type |

---

## Step 7: Value Conversion & FX Rates

| Column | Source | Calculation | Purpose |
|--------|--------|-------------|---------|
| `bid_value_local` | balance_local | `PARSE_EURO_DECIMAL(balance_local)` = Remove ".", replace "," with ".", cast to double | Position value in local currency (numeric) |
| `accrued_interest_local` | accrued_interest_local | `PARSE_EURO_DECIMAL(accrued_interest_local)` | Accrued interest in local currency (numeric) |
| `cash_value_local` | cash_balance_local | `PARSE_EURO_DECIMAL(cash_balance_local)` | Cash balance in local currency (numeric) |
| `fx_rate` | FX Rates table | `JOIN(fx_rates ON local_currency = currency)` OR `1.0` for GBP | Exchange rate to GBP for this currency |
| `bid_value_gbp` | bid_value_local, fx_rate | `IF(bid_value_local NULL OR fx_rate NULL, NULL, bid_value_local * fx_rate)` | Position value in GBP |
| `cash_value_gbp` | cash_value_local, fx_rate | `IF(cash_value_local NULL, 0.0, IF(fx_rate NULL, NULL, cash_value_local * fx_rate))` | Cash value in GBP (defaults to 0.0 if source null) |
| `accrued_interest_gbp` | accrued_interest_local, fx_rate | `IF(accrued_interest_local NULL, 0.0, IF(fx_rate NULL, NULL, accrued_interest_local * fx_rate))` | Accrued interest in GBP (defaults to 0.0 if source null) |
| `holding` | N/A | `LITERAL: NULL` | Quantity/units held (not available in Brown Shipley data) |
| `local_bid_price` | N/A | `LITERAL: NULL` | Unit price in local currency (not available in Brown Shipley data) |

**Note**: `PARSE_EURO_DECIMAL()` handles European format (1.234,56) → 1234.56:
```python
REGEXP_REPLACE(REGEXP_REPLACE(TRIM(col), ".", ""), ",", ".").cast("double")
```

---

## Step 8: Include/Remove Decision Tree

| Column | Source | Calculation | Purpose |
|--------|--------|-------------|---------|
| `policyholder_number_clean` | policyholder_number | `UPPER(TRIM(COALESCE(policyholder_number, "")))` | Normalized policy for comparison |
| `include` | Multiple | **Excel Formula (workbook-equivalent)**:<br/>`CASE`<br/>`  WHEN bid_value_gbp = 0 OR bid_value_gbp IS NULL THEN "Remove"`<br/>`  WHEN policyholder_number_clean = "" THEN "Remove"`<br/>`  WHEN policyholder_number_clean = "REMOVE*" THEN "Remove"`<br/>`  WHEN ih_policy_exists = TRUE THEN "Include"`<br/>`  ELSE "Remove"`<br/>`END` | Include/Remove flag (workbook terminology) |
| `include_flag` | include | `IF(include = "Include", "Include", "Remove")` | Include/Remove flag (pipeline terminology) |
| `exclusion_reason_code` | Multiple | `CASE`<br/>`  WHEN bid_value_gbp = 0 OR NULL → REMOVE_ZERO_VALUE`<br/>`  WHEN policyholder_number_clean = "" → REMOVE_BLANK_POLICY`<br/>`  WHEN policyholder_number_clean = "REMOVE*" → REMOVE_LITERAL_MARKER`<br/>`  WHEN ih_policy_exists = FALSE → REMOVE_NOT_IN_IH`<br/>`  ELSE NULL` (for Includes)`<br/>`END` | Reason code for exclusion (traceability) |

**Precedence (matches Excel formula)**:
1. Rule 1: Zero/blank bid value (highest priority)
2. Rule 2: Blank policy reference
3. Rule 3: Literal "REMOVE*" marker in policy
4. Rule 4: Policy exists in IH Report
5. Default: Remove

---

## Step 9: Check Columns & Decision Trace

| Column | Source | Calculation | Purpose |
|--------|--------|-------------|---------|
| `movt_percent` | movt_raw | `REGEXP_REPLACE(TRIM(COALESCE(movt_raw, "")), "%", "").cast("double")` | Movement % as numeric (removes % symbol) |
| `holdings_check_flag` | movt_percent | `CASE`<br/>`  WHEN movt_percent IS NULL → "not_evaluable"`<br/>`  WHEN movt_percent BETWEEN 98.0 AND 102.0 → "pass"`<br/>`  ELSE "fail"`<br/>`END` | Tolerance check: is Movt within 98-102%? |
| `acq_value_check_flag` | N/A | `LITERAL: "not_evaluable"` | Stub: Acquisition value check (not in Brown Shipley) |
| `decision_trace_json` | Multiple | JSON struct containing:<br/>- policy_original (client_id)<br/>- policy_mapped (policyholder_number)<br/>- policy_mapping_applied<br/>- ih_policy_exists<br/>- ih_lookup_count<br/>- bid_value_gbp<br/>- include<br/>- include_flag<br/>- identifier_chosen<br/>- source_sedol<br/>- source_isin<br/>- security_code<br/>- exclusion_reason_code<br/>- movt_percent<br/>- holdings_check_flag | Serialized decision details for audit trail |
| `data_quality_flags` | Multiple | Array of strings (nulls filtered out):<br/>- `FX_NOT_AVAILABLE` (if fx_rate IS NULL)<br/>- `POLICY_NOT_MAPPED` (if policy_mapping_applied = FALSE)<br/>- `MOVT_NOT_AVAILABLE` (if movt_percent IS NULL)<br/>- `MOVT_OUTSIDE_TOLERANCE` (if holdings_check_flag = "fail") | Data quality warnings for this row |

---

## Step 9: Schema Projection (Final Output)

| Column | Source | Calculation | Purpose |
|--------|--------|-------------|---------|
| `row_hash` | Multiple | `SHA2(CONCAT_WS("\|", period, dfm_id, policyholder_number, security_code, isin, source_row_id), 256)` | Row deduplication hash |
| `report_date` | value_date | `TO_DATE(value_date)` with format retry (dd/MM/yyyy, yyyy-MM-dd, auto) | Reporting date as DATE type |
| `transformed_at` | System | `CURRENT_TIMESTAMP()` | When this row was transformed (UTC) |

---

## Summary: Source Data Flows

```
Stage 1 Raw Data
├── positions_raw (securities, SEDOL/ISIN)
│   ├─→ balance_local → bid_value_local → bid_value_gbp
│   ├─→ accrued_interest_local → accrued_interest_gbp
│   ├─→ currency_code → local_currency
│   ├─→ client_id → (lookup Mappings) → policyholder_number
│   └─→ sedol/isin → (lookup Mappings composite key) → security_code
│
├── cash_raw (cash accounts)
│   └─→ accounting_balance → cash_value_local → cash_value_gbp
│
├── Mappings.xlsx (Reference - DFM-scoped)
│   ├─→ [UBS Ref, SL PolNo] → policyholder_number
│   └─→ [identifier, currency, final_security_code] → security_code (composite key)
│
├── IH Report.xlsx (Reference - 2 columns: policy_number, valuation)
│   └─→ policy_number → (match policyholder_number) → ih_policy_exists
│
└── FX Rates table (Reference)
    └─→ [currency, rate] → fx_rate → (multiply local values) → GBP values

Decision Tree (Excel-equivalent formula)
├─→ Rule 1: bid_value_gbp = 0/NULL? → Remove (REMOVE_ZERO_VALUE)
├─→ Rule 2: policyholder_number = ""? → Remove (REMOVE_BLANK_POLICY)
├─→ Rule 3: policyholder_number = "REMOVE*"? → Remove (REMOVE_LITERAL_MARKER)
├─→ Rule 4: ih_policy_exists? → Include
└─→ Default → Remove (REMOVE_NOT_IN_IH)

Output: individual_dfm_consolidated
└─→ Row-for-row with Stage 1 input, enriched with mappings + Include/Remove flags + traceability
```

---

## Validation Checklist

Use this to verify calculated fields match the workbook:

- [ ] **Policy Mapping**: Select 10 rows, verify `policyholder_number` matches workbook "SL PolNo" after lookup
- [ ] **Security Mapping**: Verify `security_code` matches workbook security code lookups
- [ ] **Bid Value GBP**: Compare `bid_value_gbp` calculations with workbook (balance_local × fx_rate)
- [ ] **Include/Remove**: Verify distribution and reason codes match workbook "Edited" sheet totals
- [ ] **IH Matches**: Verify `ih_policy_exists = TRUE` count matches workbook findings
- [ ] **Movt Tolerance**: Verify `holdings_check_flag` pass/fail/not_evaluable distribution
- [ ] **Decision Trace**: Spot-check JSON payloads for 5 sample rows

---

## Known TODOs

- **Holding calculation**: Deferred (not available in Brown Shipley source, stub as NULL)
- **Local Bid Price**: Deferred (not available in source, stub as NULL)
- **Acq Value Check**: Stub as "not_evaluable" (data not available for POC)
- **IH Exclude Status**: Not evaluated for POC (IH Report file only has 2 columns)
