# Research: DFM PoC — Ingestion Pipeline

## DFM-Specific Mapping Decisions

### Brown Shipley

**Source files**: `Notification.csv` (positions), `Notification - Cash.csv` (cash)

**Key design decisions**:

- **Header row detection**: The header row is not guaranteed to be on row 1. The ingestion notebook must scan the first N rows for the expected column names and use the detected header row index.
- **European decimal parsing**: All numeric fields use European format (`3.479,29`). The `raw_parsing_config.json` sets `european_decimals: true` for this DFM; the parser must always apply European mode regardless of value heuristics.
- **GBP assumption**: If no currency column is present in the source row, the system assumes GBP and writes `CURRENCY_ASSUMED_GBP` to `data_quality_flags`. If a currency is present and is not GBP, the FX rates table is consulted; if unavailable, `bid_value_gbp = null` and `FX_NOT_AVAILABLE` is flagged.
- **MV_001 evaluability**: Brown Shipley does not reliably provide a bid price column. Most rows are expected to produce `MV_001` events with `status = not_evaluable`. This is acceptable PoC behaviour — the spec prefers flagged uncertainty over guessed values.
- **Cash file mapping**: `Accounting Balance` from the cash file maps to `cash_value_local`. This is merged with position rows by `Client ID`.

**Canonical column mapping**:

| Canonical | Source |
|-----------|--------|
| `policy_id` | `Client ID` |
| `report_date` | `Value Date` |
| `security_id` | `ISIN` |
| `bid_value_local` | `Balance` |
| `accrued_interest_local` | `Accrued Interest` |
| `cash_value_local` | `Accounting Balance` (cash file) |
| `local_currency` | Source column if present; else GBP assumed |

---

### WH Ireland

**Source file**: Standard Life Valuation Data XLSX (single sheet)

**Key design decisions**:

- **GBP priority chain**: Five priority levels must be applied in order. The first level that yields a GBP value terminates the chain:
  1. `Position Currency == GBP` → use `Settled Market Value (PC)` directly; `fx_rate = 1.0`
  2. `Account Base Currency == GBP` → use `Settled Market Value (ABC)`
  3. `Position to Account Exchange Rate` present → convert `Settled Market Value (PC)` using that rate
  4. `fx_rates.csv` available → join on `Position Currency` and convert
  5. Else → `bid_value_gbp = null`; flag `FX_NOT_AVAILABLE`
- **Cash and accrued defaulted to 0**: WH Ireland does not provide cash or accrued interest fields. Both are set to 0 and flagged with `CASH_DEFAULTED` and `ACCRUED_DEFAULTED`.
- **No row-hash complexity**: Single-file, single-sheet source simplifies de-duplication; standard row-hash on source fields is sufficient.

**Canonical column mapping**:

| Canonical | Source |
|-----------|--------|
| `policy_id` | `Account Number` |
| `isin` | `ISIN` |
| `holding` | `Settled Quantity` |
| `local_bid_price` | `Display Price` |
| `bid_value_local` | `Settled Market Value (PC)` |
| `local_currency` | `Position Currency` |
| `report_date` | `Position as of Date` |
| `cash_value_gbp` | 0 (default) |
| `accrued_interest_gbp` | 0 (default) |

---

### Pershing

**Source files**: `Positions.csv` (primary), `PSL_Valuation_Holdings_YYYYMMDD_*.csv` (secondary/backfill)

**Key design decisions**:

- **Two-file approach with precedence**: `Positions.csv` is the authoritative source. Valuation holdings provide backfill only for policies not present in `Positions.csv`. A policy present in `Positions.csv` is never overridden by valuation holdings data.
- **Row-hash de-duplication**: Both files are independently de-duplicated before the merge. This prevents double-counting when multiple copies of the same file are placed in the landing zone.
- **Pershing GBP chain**:
  1. `ReportingMarketValueISO == GBP` → use `ReportingMarketValue`
  2. `LocalCurrencyISO == GBP` → use `MarketValue`
  3. `FXRate` present and reporting currency is GBP → `MarketValue * FXRate`; flag `FX_RATE_ASSUMED`
  4. Else → `bid_value_gbp = null`; flag `FX_NOT_AVAILABLE`
- **Backfill detection**: After loading `Positions.csv`, collect the set of `policy_id` values. Load valuation holdings and keep only rows whose `PSLAccountReference` is not in the positions set.
- **Fallback policy column**: If `AccountNumber` is absent, fall back to `PortfolioNumber`. If `ReportDate` is absent, fall back to `PositionDate`.

**Positions.csv canonical column mapping**:

| Canonical | Source |
|-----------|--------|
| `policy_id` | `AccountNumber` (fallback: `PortfolioNumber`) |
| `report_date` | `ReportDate` (fallback: `PositionDate`) |
| `isin` | `ISIN` |
| `holding` | `Quantity` |
| `local_bid_price` | `Price` |
| `local_currency` | `LocalCurrencyISO` |
| `bid_value_local` | `MarketValue` |

**Valuation holdings canonical column mapping**:

| Canonical | Source |
|-----------|--------|
| `policy_id` | `PSLAccountReference` |
| `report_date` | `ValueDate` |
| `holding` | `Holding` |
| `local_bid_price` | `Price` |
| `bid_value_local` | `Value` |
| `local_currency` | `CCYOfTheAsset` |
| `accrued_interest_local` | `AccruedInterest` |

---

### Castlebay

**Source file**: `Cde OSB Val 31Dec25.xlsx` (two sheets: `Customer 1`, `Customer 2`)

**Key design decisions**:

- **Multi-sheet parsing**: Both `Customer 1` and `Customer 2` sheets must be ingested. The sheet name is written to `source_sheet` in `canonical_holdings` for traceability.
- **Header row 3**: The header is on row 3 (1-based). `raw_parsing_config.json` sets `header_row_index_1based: 3`. Rows 1–2 are skipped.
- **Filename date inference**: No date column exists in the source. The `report_date` is extracted from the filename using the pattern `DDMmmYY` (e.g., `31Dec25` → `2025-12-31`). Flag `DATE_FROM_FILENAME` is always set for Castlebay rows.
- **Currency mapping via JSON**: The source contains a text `Currency Description` field (e.g., "Pound Sterling"). `currency_mapping.json` (Castlebay section) maps this to ISO codes. If a description is not found, flag `CURRENCY_UNKNOWN` and leave `local_currency = null`.
- **Cash and accrued defaulted to 0**: Similar to WH Ireland; both defaulted with flags.
- **Security ID fallback**: Use `ISIN Code` as primary `security_id`; fall back to `SEDOL` if ISIN is absent.

**Canonical column mapping**:

| Canonical | Source |
|-----------|--------|
| `policy_id` | `Account Name` |
| `isin` | `ISIN Code` |
| `security_id` | `ISIN Code` (fallback: `SEDOL`) |
| `holding` | `Quantity Held` |
| `local_bid_price` | `Price in Stock Currency` |
| `bid_value_local` | `Value in Market` |
| `local_currency` | Derived from `Currency Description` via `currency_mapping.json` |
| `report_date` | Inferred from filename |
| `cash_value_gbp` | 0 (default) |
| `accrued_interest_gbp` | 0 (default) |
| `acq_cost` | Optional column; null + `ACQ_COST_UNPARSEABLE` if absent or invalid |

---

## Framework Decisions

### Numeric Parsing — Dual-Mode

**Decision**: Support both UK/US format (`13,059.70`) and European format (`3.479,29`). The parsing mode is config-driven per DFM via `european_decimals` in `raw_parsing_config.json`.

**Detection heuristic** (for DFMs not in fixed mode): If a string value contains both `.` and `,`, and `,` appears after the last `.`, treat as European. Otherwise treat as UK/US.

**Rationale**: Brown Shipley uses European format. All other DFMs use UK/US. Mixing the two in a single parser without config would silently corrupt numeric values.

---

### Date Parsing — Four Supported Formats

**Decision**: Support in order:
1. `dd-MMM-yyyy` — e.g., `31-Dec-2025`
2. `dd/MM/yyyy` — e.g., `31/12/2025`
3. ISO datetime — e.g., `2025-12-31T00:12:00.000`
4. Filename inference — extract `DDMmmYY` or `DDMmmYYYY` from filename; flag `DATE_FROM_FILENAME`

**Rationale**: Each DFM uses a different date representation. A single multi-format parser avoids DFM-specific date logic scattered across notebooks.

---

### Currency Normalisation — Five-Step GBP Priority Chain

**Decision**: Apply in order; stop at first successful result:
1. `local_currency == GBP` → `fx_rate = 1.0`, `bid_value_gbp = bid_value_local`
2. DFM provides a GBP-denominated value column (e.g., WH Ireland `ABC`, Pershing `ReportingMarketValue`) → use directly
3. DFM provides a position-level FX rate → convert `bid_value_local`; flag `FX_RATE_ASSUMED`
4. `fx_rates.csv` available for `local_currency` → convert `bid_value_local`
5. → `bid_value_gbp = null`; flag `FX_NOT_AVAILABLE`

**Rationale**: Different DFMs provide different levels of FX information. A shared chain with per-step DFM hooks ensures consistent handling without duplicating fallback logic.

---

### Row-Hash De-duplication

**Decision**: Compute SHA-256 (or MD5 for PoC) over the concatenated string representation of the deterministic canonical fields: `(dfm_id, source_file, source_sheet, source_row_id, policy_id, security_id, holding, local_bid_price, local_currency)`. Write `row_hash` as a column in `canonical_holdings`. Use MERGE upsert matching on `row_hash` to prevent duplicate rows.

**Rationale**: The landing zone has no deduplication guarantees. Analysts may accidentally place the same file twice. Row-hash prevents double-counting without requiring a manual clean-up step.

---

### Data Quality Flags

All flags are written to `data_quality_flags` (ArrayType\<string\>) on every `canonical_holdings` row.

| Flag | When Set |
|------|----------|
| `CURRENCY_ASSUMED_GBP` | No currency column present in source; GBP assumed (Brown Shipley) |
| `FX_NOT_AVAILABLE` | All five GBP conversion steps exhausted; `bid_value_gbp = null` |
| `FX_RATE_ASSUMED` | Position-level FX rate used (Pershing step 3) |
| `PRICE_ABSENT` | `local_bid_price` field absent or null in source |
| `DATE_FROM_FILENAME` | `report_date` inferred from filename (Castlebay) |
| `ACQ_COST_UNPARSEABLE` | Acquisition cost column present but could not be parsed |
| `CASH_DEFAULTED` | `cash_value_gbp` set to 0 because source has no cash field |
| `ACCRUED_DEFAULTED` | `accrued_interest_gbp` set to 0 because source has no accrued field |
| `CURRENCY_UNKNOWN` | `Currency Description` not found in `currency_mapping.json` (Castlebay) |
