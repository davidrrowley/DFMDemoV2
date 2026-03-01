# Stakeholder notes

## Context

The DFM PoC digitises and automates a monthly manual process run by the investment operations team. Currently, reconciliation across four Discretionary Fund Managers (Brown Shipley, WH Ireland, Pershing, Castlebay) is performed entirely in Excel using a combination of:

- Three macro-driven import steps (FX Rates, ISIN Mappings, IH Report from Spice)
- Manual copy-paste of DFM confirmation data into an `Original Data` tab
- Formula propagation in an `Edited` tab with manual lookup expansion for `#N/A` errors
- A `tpir_load` tab built by filtering and paste-special from the `Edited` tab
- A standalone TPIR Upload Checker tool run before loading to ADS
- Manual ADS load

This process creates significant operational risk (key-person dependency, error-prone copy-paste, no automated audit trail) and takes approximately a full business day per period.

The PoC replaces this entirely with a Microsoft Fabric pipeline. The tpir_load contract (13-column schema, Policyholder_Number as key) is preserved exactly so that ADS is unaffected.

## Priorities

1. **Preserve the tpir_load contract** — The exact 13-column schema loaded to ADS must not change. ADS is a downstream system outside the programme's control.
2. **Automate the full pipeline end-to-end** — From DFM file receipt through TPIR check to ADS load, with no manual steps in between (only the upload of DFM files and config exports remains manual for the PoC).
3. **Make validation failures visible and actionable** — MV_001 (±2% market value check), MAP_001 (unmapped securities), and POP_001 (unmapped policies) must produce clear, downloadable reports so analysts can investigate and resolve issues.
4. **Maintain a full audit trail** — Every run must produce a `run_audit_log` row per DFM and a `reconciliation_summary.json` for review and evidence.
5. **Idempotent re-runs** — Re-running for the same period after fixing a lookup gap must be safe; no duplicate data in ADS.

## Risks and concerns

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| FX rates not available for all currencies | Medium | High — non-GBP positions get null bid_value_gbp and MV_001 not_evaluable | Analyst must upload fx_rates.csv before run; pipeline flags affected rows with FX_NOT_AVAILABLE |
| ISIN/SEDOL lookup gaps (new securities) | High — likely every period | Medium — those rows fail MAP_001 | Analyst adds to security_master.csv; re-run is idempotent |
| IH policy mapping mismatches | Medium | High — unmapped policies excluded from tpir_load | POP_001 enabled by default; analyst resolves via Spice before ADS load |
| Brown Shipley European decimal mis-parsing | Low (config-controlled) | High — all numeric values corrupted | european_decimals flag in raw_parsing_config.json is the control; acceptance tests validate |
| ADS load failure after TPIR check passes | Low | High — gap in ADS data for the period | ads_load_status tracked in run_audit_log; retry with same run_id is idempotent |
| Brown Shipley price data absent | Certain (by design) | Low — MV_001 not_evaluable is expected | Documented assumption in spec.md; no action needed |
