# Security Baseline: DFM PoC Ingestion Platform

> **Purpose:** Threat model, security requirements, and controls for the DFM PoC.
> This is a PoC running in a single Fabric workspace. Production security hardening
> is explicitly out of scope but known gaps are documented here for future reference.

---

## PoC Scope and Limitations

This baseline applies to a Proof of Concept running in a Microsoft Fabric workspace with a single
user (or a small trusted team). It is **not** a production security baseline. The following
enterprise security features are explicitly out of scope for the PoC:

- Multi-user authentication and role-based access control (RBAC) within notebooks
- Row-level security on Delta tables
- Automated secret rotation
- Network isolation / private endpoints for OneLake
- SIEM integration, automated alerting, or SOC monitoring
- Formal penetration testing

These gaps must be addressed before any production deployment.

---

## Threat Model

| Asset | Threat | Impact | PoC Mitigation |
|---|---|---|---|
| **Client portfolio data** in `canonical_holdings` and source files | Unauthorised access to OneLake | Privacy breach; regulatory violation | Access governed by existing Fabric workspace permissions. Only authorised workspace members can access data. |
| **Config files** (`dfm_registry.json`, `rules_config.json`, etc.) | Sensitive thresholds or mappings exposed in source control | Competitive or operational risk | Config files may be committed to source control. They must not contain credentials, client names, or portfolio totals. |
| **FX rates and connection strings** | Secrets in source control | Credential compromise | Connection strings and API keys must be managed via Fabric environment secrets or Fabric Key Vault integration — never committed to files. |
| **Source DFM files** in landing zone | Accidental overwrite or deletion | Data loss; re-run impossible | OneLake versioning provides point-in-time recovery. Source files should not be deleted after ingestion. |
| **Delta tables** | Accidental table drop or schema change | Run history lost | Fabric Lakehouse table versioning (Delta time travel) provides recovery. |
| **Run outputs** in `/Files/output/` | Unauthorised access to reconciliation reports | Privacy breach | Access governed by Fabric workspace permissions. Output CSVs and JSON contain portfolio-level aggregates. |
| **Notebook code** | Injection of malicious logic | Pipeline corruption | Notebooks are stored in Fabric workspace; access controls apply. AI-generated code must be reviewed before execution. |

---

## Security Requirements

### R-SEC-01 — No Credentials in Source Control

**Requirement:** Config files committed to the repository must not contain credentials, connection
strings, API keys, storage account keys, or service principal secrets.

**Implementation:**
- `dfm_registry.json`, `raw_parsing_config.json`, `rules_config.json`, `currency_mapping.json`
  contain only structural config (no secrets).
- FX rate files and connection parameters are managed in Fabric environment variables or
  Key Vault references.
- `.gitignore` must exclude any files containing credentials.

**Validation:** Review all committed config files. Run `git grep` for common secret patterns
(connection string, account key, password, secret) before any commit.

---

### R-SEC-02 — Workspace Access Control

**Requirement:** Access to the Fabric workspace, OneLake, and Delta tables is governed by existing
Fabric workspace permissions. Only members of the workspace should be able to read source files
or query Delta tables.

**Implementation:**
- No additional access control is implemented within the PoC notebooks.
- Workspace membership must be reviewed before the PoC runs against real client data.

**Validation:** Confirm workspace member list matches the expected analyst team.

---

### R-SEC-03 — Client Data Handling

**Requirement:** Source DFM files (which contain client portfolio data) must be stored only in the
designated OneLake landing zone. They must not be copied to local machines, email, or other systems.

**Implementation:**
- Source files are uploaded directly to OneLake via the Fabric interface or automated pipeline.
- Analysts working on the PoC must not download source files to personal devices.

**Validation:** Process documented in `quickstart.md`. Analyst acknowledgement required.

---

### R-SEC-04 — Audit Trail as Data Lineage

**Requirement:** The `run_audit_log`, `parse_errors`, and `schema_drift_events` tables provide
data lineage for every run. These must be retained and not truncated between runs.

**Implementation:**
- Tables are append-only by design; each run adds rows with a unique `run_id`.
- No notebook truncates or deletes from governance tables.
- Delta time travel provides additional point-in-time history.

**Validation:** After multiple runs, verify that `run_audit_log` retains all historical rows.

---

### R-SEC-05 — AI-Assisted Code Review

**Requirement:** All AI-generated code touching finance calculations (GBP conversion, MV
recalculation, policy aggregation) must be reviewed by a human before execution against real data.

**Implementation:**
- Pull request or notebook change review required before running against real client data.
- AI-generated boilerplate (schema creation, logging, config loading) does not require finance review.

**Validation:** Code review sign-off recorded in PR or notebook comment.

---

## Compliance Notes

The DFM PoC processes client portfolio data (positions, valuations, policy numbers). The following
compliance considerations apply:

| Area | Note |
|---|---|
| **GDPR / Data Privacy** | Portfolio data is pseudonymised by policy number. Policy numbers should not be mapped to client names in PoC outputs. |
| **Data Retention** | Source files and Delta tables should follow the firm's data retention policy. The PoC does not implement automated retention. |
| **Audit Obligations** | `run_audit_log` and `parse_errors` provide a record of data transformation. These should be retained for the period required by the firm's audit policy. |
| **Regulatory Reporting** | `tpir_load_equivalent` and `policy_aggregates` are inputs to regulatory reporting. Any discrepancy between PoC outputs and Excel outputs must be investigated before the PoC is used to inform reporting. |

---

## Known Gaps (Post-PoC Production Hardening Required)

The following gaps must be addressed before any production deployment:

1. **Authentication:** Notebooks currently rely on Fabric workspace identity. Production should implement explicit service principal authentication with minimum permissions.
2. **Row-level security:** `canonical_holdings` and `policy_aggregates` contain data for multiple DFMs. Production should implement row-level security by DFM and policy ownership.
3. **Secret management:** FX rates and any future API connections should use Fabric Key Vault integration with automated rotation.
4. **Network isolation:** Production should use private endpoints for OneLake access, preventing public internet exposure.
5. **Penetration testing:** A formal security assessment should be conducted before production use.
6. **Automated scanning:** SAST and dependency scanning should be added to any CI/CD pipeline that builds shared library code.

---

## See Also

- [architecture.md](architecture.md) — System boundaries and data flow
- [nfr.md](nfr.md) — Non-functional requirements (NFR-08 covers PoC constraints)
- [quickstart.md](quickstart.md) — Data handling instructions for analysts
