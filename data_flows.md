# Data flows

## Core stage flow

### Stage 1 - Source DFM raw files

```text
DFM files
  -> /Files/landing/period=YYYY-MM/dfm=<dfm_id>/source/
  -> adapter profile discovery and parsing
  -> source_dfm_raw
  -> parse_errors + schema_drift_events
```

### Stage 2 - Individual DFM consolidated template

```text
source_dfm_raw
  -> profile-driven standardization
  -> individual_dfm_consolidated
  -> include/remove decisions and trace metadata
  -> dq_results + dq_exception_rows
```

### Stage 3 - Aggregated DFMs consolidated template

```text
individual_dfm_consolidated (gate-passing rows)
  -> aggregated_dfms_consolidated
  -> policy_aggregates
  -> tpir_load_equivalent
  -> reports and reconciliation summary
```

## Publish control flow

```text
dq_results
  -> evaluate blocking severities
  -> if pass: publish to Stage 3
  -> if fail: retain exceptions, block publication for failed scope
```

## External interfaces

| System | Direction | Purpose |
|---|---|---|
| DFM source systems | Inbound | Holdings and valuation source files |
| FX / mapping references | Inbound | Currency and mapping controls |
| ADS | Outbound | Consumer of tpir contract output |

## Trust boundaries

- Landing zone: untrusted source input.
- Config zone: controlled analyst input.
- Pipeline compute: trusted internal processing.
- Output zone: controlled published artifacts.
