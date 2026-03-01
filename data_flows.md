# Data flows

## Core flows

The DFM PoC pipeline processes monthly holdings data through four sequential flows:

### Flow 1 — DFM File Landing → Ingestion → `canonical_holdings`

```
DFM custodians
  └─► Analyst uploads files to OneLake landing zone
        /Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/
  └─► nb_run_all invokes nb_ingest_<dfm> per DFM
  └─► Each DFM notebook:
        - Discovers and reads source files (CSV / XLSX)
        - Parses using raw_parsing_config.json (decimals, dates, headers)
        - Maps source columns to canonical schema
        - Applies GBP normalisation (5-step FX chain)
        - Row-hash de-duplication (SHA-256 MERGE)
        - Writes to canonical_holdings Delta table
        - Emits parse_errors and schema_drift_events
```

### Flow 2 — `canonical_holdings` → Validation → `validation_events`

```
canonical_holdings
  └─► nb_validate
        - MV_001: holding × local_bid_price × fx_rate vs bid_value_gbp (±2%)
        - DATE_001: stale report date check (>5 working days after month-end)
        - VAL_001: policy with zero cash and zero bid value
        - MAP_001: unmapped security_id (join enrichment against security_master.csv)
        - POP_001: unmapped DFM policy (join against policy_mapping.csv)
  └─► validation_events Delta table
```

### Flow 3 — `canonical_holdings` → Aggregation → `tpir_load_equivalent` + `policy_aggregates`

```
canonical_holdings
  └─► nb_aggregate
        - policy_aggregates: GBP totals grouped by (period, run_id, dfm_id, policy_id)
        - tpir_load_equivalent: 13-column projection of canonical_holdings
          (Policyholder_Number, Security_Code, ISIN, Other_Security_ID, ID_Type,
           Asset_Name, Acq_Cost_in_GBP, Cash_Value_in_GBP, Bid_Value_in_GBP,
           Accrued_Interest, Holding, Loc_Bid_Price, Currency_Local)
  └─► policy_aggregates Delta table
  └─► tpir_load_equivalent Delta table
  └─► Report 1 CSVs (per DFM): /Files/output/period=YYYY-MM/run_id=<run_id>/report1_<dfm_id>.csv
  └─► Report 2 roll-up CSV: report2_rollup.csv
  └─► reconciliation_summary.json
```

### Flow 4 — `tpir_load_equivalent` → TPIR Check → ADS Load

```
tpir_load_equivalent
  └─► nb_tpir_check
        - TC-001: schema completeness (all 13 columns present)
        - TC-002: non-empty dataset
        - TC-003: Policyholder_Number not null
        - TC-004: Bid_Value_in_GBP not null for non-cash rows
        - TC-005: Currency_Local is a valid ISO-4217 code
        - TC-006: no REMOVE-status policies in output
        - TC-007: row count matches canonical_holdings
  └─► tpir_check_result.json (status: passed | failed)
  └─► [if passed] nb_ads_load
        - Batches records to ADS REST API: POST /api/v1/tpir/load
        - Polls for committed status: GET /api/v1/tpir/load/{runId}
  └─► ADS (Asset Data Store)
```

---

## External systems

| System | Direction | Data | Format |
|--------|-----------|------|--------|
| Brown Shipley | Inbound | Holdings positions + cash | CSV (European decimals) |
| WH Ireland | Inbound | Standard Life Valuation Data | XLSX |
| Pershing | Inbound | Positions + PSL valuation holdings | CSV + XLSX |
| Castlebay | Inbound | Valuation holdings (two customer sheets) | XLSX |
| Treasury / Bloomberg | Inbound | Monthly FX spot rates | Manual export → `fx_rates.csv` |
| Spice (IH policy system) | Inbound | Policy reference mapping + IH Report | Manual export → `policy_mapping.csv` |
| ISIN Master List workbook | Inbound | ISIN/SEDOL/asset name lookup | Manual export → `security_master.csv` |
| ADS (Asset Data Store) | Outbound | TPIR-format holdings for the period | REST API (JSON) |

---

## Trust boundaries

| Zone | Contents | Trust level | Controls |
|------|----------|-------------|----------|
| **Landing zone** | `/Files/landing/` DFM source files | Untrusted — externally sourced | File type validation, schema drift detection, parse error isolation |
| **Config zone** | `/Files/config/` FX rates, security master, policy mapping | Trusted analyst-prepared | Analyst review before upload; validation on load |
| **Pipeline compute** | Fabric notebooks, Delta tables | Trusted — internal Fabric workspace | Fabric workspace access controls; Managed Identity for ADS calls |
| **Output zone** | `/Files/output/` reports, TPIR check result | Trusted — pipeline produced | Read-only after run; run_id scoped |
| **ADS** | Asset Data Store | Trusted downstream | Bearer token (Azure Managed Identity); ADS-side idempotency on run_id |
