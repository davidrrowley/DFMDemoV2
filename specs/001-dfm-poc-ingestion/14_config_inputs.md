# 14 — Configuration Inputs

This document specifies the three reference-data config files that must be present in `/Files/config/` before any pipeline run. They represent the automated equivalents of the three macro-driven import steps in the original Excel process (Import FX Rates, Import ISIN Mappings, Import IH Report).

---

## 14.1 FX Rates (`fx_rates.csv`)

### Purpose

Provides exchange rates from local currencies to GBP, consumed at step 3 of the currency normalisation chain in `04_ingestion_framework.md`. Without this file, non-GBP positions fall through to `bid_value_gbp = null` with the `FX_NOT_AVAILABLE` data quality flag.

### Source

Manual export from the treasury FX system (or Bloomberg) by the investment operations team at month-end. The rates must reflect the close-of-period spot rates for the relevant valuation date.

### Required Schema

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `currency_code` | string | ISO-4217 3-letter code | `USD` |
| `rate_to_gbp` | decimal | Units of local currency per 1 GBP | `1.2543` |
| `effective_date` | date | YYYY-MM-DD rate date | `2025-12-31` |

### Upload Path

```
/Files/config/fx_rates.csv
```

### Cadence

Once per period, before the run is triggered. The file is overwritten each period.

### Validation

On load, the pipeline checks:
- All required columns present
- `currency_code` is a 3-character string
- `rate_to_gbp` is a positive non-zero number
- `effective_date` is parseable as a date

If the file is absent or malformed, step 3 of the FX chain is skipped; affected rows receive `FX_NOT_AVAILABLE`.

### Failure Handling

Missing `fx_rates.csv` does **not** block the run. Rows without a matching `currency_code` receive `bid_value_gbp = null` and the `FX_NOT_AVAILABLE` flag, making `MV_001` `not_evaluable` for those rows. This mirrors the original Excel process where missing FX rates produced blank GBP columns.

---

## 14.2 Security Master (`security_master.csv`)

### Purpose

Provides the ISIN/SEDOL → canonical security identity and name lookup, equivalent to the ISIN Mappings table in the original Excel workbook. This table is used to enrich `security_id` and `asset_name` when source files provide only partial identifiers. When a row has a null `security_id` after ingestion, the pipeline attempts a join to this table before raising a `MAP_001` exception.

### Source

Derived from the ISIN Master List workbook maintained by the investment operations team. The CSV is exported from that workbook and uploaded prior to each run.

**Maintenance workflow** (triggered when `MAP_001` fires for an unmapped security):

1. Identify the new ISIN/SEDOL and asset name from the DFM source file.
2. Look up the security details (asset class, currency, full name) via an external reference (Bloomberg, Google Finance, or the DFM's own fund factsheet).
3. Add a new row to the ISIN Master List workbook.
4. Re-export the CSV and upload to `/Files/config/security_master.csv`.
5. Re-run the pipeline for the affected period.
6. Confirm `MAP_001` no longer fires for that security.

### Required Schema

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `isin` | string | 12-character ISIN code (nullable if SEDOL only) | `GB0031348658` |
| `sedol` | string | 7-character SEDOL code (nullable if ISIN only) | `3134865` |
| `asset_name` | string | Canonical display name for the asset | `Legal & General UK Index` |
| `asset_class` | string | One of: `equity`, `bond`, `cash`, `fund`, `other` | `fund` |
| `currency_iso` | string | ISO-4217 code for the security's native currency | `GBP` |

At least one of `isin` or `sedol` must be non-null per row.

### Upload Path

```
/Files/config/security_master.csv
```

### Lookup Logic

During ingestion, after canonical mapping but before writing to `canonical_holdings`:

1. If `security_id` (ISIN) is non-null → attempt join on `isin` column; enrich `asset_name` if blank.
2. If `security_id` is null but a SEDOL is present in the source → attempt join on `sedol` column; populate `security_id` from `isin` if found.
3. If no match → leave `security_id` null; `MAP_001` will fire.

### Relationship to MAP_001

`MAP_001` in `05_validations.md` is evaluated **after** the enrichment join above. A `MAP_001` exception means a security is absent from `security_master.csv` and the analyst must add it per the maintenance workflow above.

---

## 14.3 IH Policy Mapping (`policy_mapping.csv`)

### Purpose

Maps DFM-originated policy references to the canonical IH (Insurance Holdings / Spice) policy identifiers. This is the automated equivalent of importing the IH Report in the original Excel process. It enables `POP_001` to detect DFM positions whose policy reference cannot be matched in the IH system — a critical reconciliation check.

### Source

The IH Report is generated monthly from the Spice policy administration system by the operations team. It is available at:

```
\\CORP\FILE\Phoenix\Finance\Restrict\OPS\Assets Team\PRODUCTION\SLIL\Monthly Asset Reports\DFM\Administration\
```

The raw IH Report must be transformed into the CSV schema below before upload. This transformation is currently a manual step (copy-paste from the IH Report output into the CSV template).

**Maintenance workflow** (triggered when `POP_001` fires for an unmapped policy):

1. Check the DFM policy reference against the IH Report — confirm whether the policy exists in Spice.
2. If **the policy exists in Spice**: verify the DFM reference matches the Spice reference exactly (check for leading zeros, format differences). If they match, the DFM is using an alternative reference format — add a mapping row to `policy_mapping.csv`.
3. If **the policy does not exist in Spice**: the DFM is holding a position for an unknown policy — flag to the DFM for investigation. Do not add to `policy_mapping.csv` until resolved.
4. If **the policy is a known exception** (e.g. a terminated policy still appearing in the DFM file): add the row to `policy_mapping.csv` and mark `status = REMOVE` to indicate it should be excluded from the TPIR load.
5. Re-upload `policy_mapping.csv` and re-run validation for the affected period.

### Required Schema

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `dfm_id` | string | DFM identifier from `dfm_registry.json` | `brown_shipley` |
| `dfm_policy_ref` | string | Policy reference as it appears in DFM source files | `PL123456` |
| `ih_policy_ref` | string | Canonical IH/Spice policy reference | `001234560` |
| `status` | string | `ACTIVE` or `REMOVE` | `ACTIVE` |

`status = REMOVE` causes the row to be excluded from `tpir_load_equivalent` during aggregation (it is still ingested into `canonical_holdings` for audit).

### Upload Path

```
/Files/config/policy_mapping.csv
```

### Relationship to POP_001

`POP_001` in `05_validations.md` joins `canonical_holdings` on `(dfm_id, policy_id)` against this file. Rows with no match produce a `fail` event. Rows with `status = REMOVE` produce a `warning` event (ingested but excluded from TPIR load).

---

## Summary: Config File Readiness Checklist

Before triggering `nb_run_all` for any period, confirm all three files are present and current:

| File | Path | Required? | If absent |
|------|------|-----------|-----------|
| `fx_rates.csv` | `/Files/config/fx_rates.csv` | Recommended | Non-GBP rows get `FX_NOT_AVAILABLE`; run proceeds |
| `security_master.csv` | `/Files/config/security_master.csv` | Recommended | All rows with unmapped ISINs trigger `MAP_001` exceptions |
| `policy_mapping.csv` | `/Files/config/policy_mapping.csv` | Required for POP_001 | `POP_001` is `not_evaluable` for all rows; run proceeds |
