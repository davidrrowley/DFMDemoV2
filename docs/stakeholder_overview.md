# DFM AI-Powered Reconciliation — Stakeholder Overview

**Version:** 1.1  
**Date:** March 2026  
**Audience:** Business stakeholders, investment operations leadership, compliance  
**Status:** Draft for review

---

## What is this project?

Every month, the investment operations team reconciles holdings data from four external fund
managers — Brown Shipley, WH Ireland, Pershing, and Castlebay. At the moment, this is done
almost entirely by hand using a set of Excel workbooks. Data is copied and pasted between
spreadsheets, reformatted, checked, and eventually loaded into the firm's downstream systems.

This project — the **DFM AI-Powered Reconciliation PoC** — replaces that manual process with
an AI-augmented data pipeline. Once the PoC is running, what currently takes the best part of a
working day will be reduced to a few minutes of preparation and a single button press. Beyond
pure automation, the pipeline uses Azure OpenAI to assist at the edges of the process: when
column layouts change unexpectedly, when security names don't quite match, and when the analyst
needs a plain-English summary of what happened — not five separate reports to reconcile.

---

## What is the current process and what is wrong with it?

The current process works but carries meaningful risk. Here is how a typical month looks today:

1. The team receives files from each of the four fund managers — in different formats, with
   different column layouts, and in some cases with different conventions for how numbers are
   written.
2. Those files are manually copied into a master Excel workbook. Each fund manager has its own
   tab, and formulas are adjusted by hand to handle the differences between suppliers.
3. FX rates, security lookup tables, and policy mappings are pulled from other spreadsheets
   and pasted in.
4. The team steps through a series of lookup columns, manually fixing any `#N/A` errors where
   a security or policy cannot be found in the master list.
5. The final data is filtered and pasted into a "TPIR load" tab. A separate checker tool is
   run to confirm the data is valid before it is loaded into the downstream system (ADS).
6. The analyst loads the data manually.

**The problems with this approach include:**

- **It relies on one or two people who know the process.** If they are absent, the month-end
  cannot be completed without significant effort to work it out from scratch.

- **There is no audit trail.** It is not possible to prove automatically which source file was
  used, what was changed, or whether a particular lookup was correct. Answering audit questions
  requires digging back through emails and spreadsheets.

- **Errors are hard to catch.** Copy-paste mistakes, formula overwrites, and missed `#N/A`
  errors can make it into the downstream system. Some issues are only discovered after the fact.

- **It does not scale.** If the firm adds a fifth fund manager, or if the volume of holdings
  grows, the manual workload increases proportionally. There is no practical way to automate
  checks or validations in the current Excel model.

---

## What will the PoC deliver?

The PoC demonstrates an end-to-end automated pipeline that handles every meaningful step of the
current process. Here is what it does, in plain terms:

### Step 1 — Files are collected automatically

Each month, the analyst uploads the fund manager files to a secure folder (the "landing zone").
The pipeline detects the files and knows how to read each one — including handling differences
in number formats, date styles, and layout between the four suppliers.

### Step 2 — Data is standardised into a single view

All four fund managers' data is converted into a single consistent format expressed in GBP —
the "canonical holdings" dataset. Every row is traceable back to the exact source file it came
from.

### Step 3 — Checks are run automatically

Instead of the analyst manually checking numbers in Excel, the pipeline runs a set of
deterministic validation rules against every row:

- **Market Value Check** — does the listed value agree with the pipeline's own recalculation
  of holdings × price × FX rate (within ±2%)?
- **Staleness Check** — is the price date recent enough to be reliable?
- **Missing Value Check** — are there any rows with a zero or missing value that might indicate
  a data problem?
- **Security Mapping Check** — can every security be matched to the firm's master security list?
- **Policy Mapping Check** — can every fund manager policy reference be matched to the firm's
  internal policy identifier?

Every check is recorded, including cases where a check is acknowledged as not applicable. This
creates a full, queryable record of what was checked and what was found.

### Step 4 — Aggregated totals are produced automatically

The pipeline produces policy-level cash, bid value, and accrued interest totals — exactly the
same figures that analysts currently derive using Excel `SUMIFS` formulas. These can be directly
compared against the fund managers' own reporting to confirm the numbers reconcile.

### Step 5 — A quality gate is run before any data is loaded

Before anything is submitted to the downstream ADS system, the pipeline runs a dedicated
pre-load check (the TPIR Upload Checker). This is the automated version of the manual checker
tool used today. It validates that the output data is structurally complete, all policy numbers
are present, values are non-null for non-cash positions, and currencies are valid. Only once all
blocking checks pass does the pipeline proceed.

### Step 6 — Data is loaded automatically

The validated data is submitted to ADS via a secure API call. The pipeline waits for ADS to
confirm the data has been committed and records the outcome. The 13-column data contract that
ADS currently expects is preserved exactly — ADS sees no difference in what it receives.

### Step 7 — A full audit record is written

For every run, the pipeline records:
- Which fund manager files were processed and how many rows were ingested.
- Which validation checks passed, failed, or could not be evaluated, and why.
- Whether the TPIR check passed, and whether the ADS load was committed.
- A machine-readable reconciliation summary showing GBP totals by fund manager.

This audit record is permanently stored and is available for review or regulatory enquiry at
any time.

---

## What outputs does it produce?

After a successful run, the operations team receives:

| Output | What it is |
|--------|------------|
| **Per-DFM report (×4)** | A CSV file per fund manager showing their holdings in the standardised format, with validation flags |
| **Roll-up report** | A single combined CSV covering all four fund managers |
| **Reconciliation summary** | A structured JSON file showing GBP totals by DFM for tie-out |
| **TPIR check result** | A pass/fail record showing which quality checks ran and what any failures were |
| **Run audit log** | A database record showing the full outcome of every step for every fund manager |

---

## What does the analyst still need to do?

The PoC automates everything that can be automated at this stage. There are three short
preparation steps the analyst does manually before kicking off the pipeline each month:

1. **Upload the FX rates file** — Exchange rates for the period, sourced from the firm's
   approved market data provider.
2. **Upload the security master file** — The current ISIN/security lookup table, exported from
   the firm's ISIN Master List workbook.
3. **Upload the policy mapping file** — The current DFM-to-IH policy mapping table, exported
   from Spice.

Once these three files are in place, the analyst uploads the fund manager files to the landing
zone and triggers the pipeline. Everything else is automated.

---

## What are the benefits?

| Benefit | Detail |
|---------|--------|
| **Time saving** | What currently takes most of a working day is reduced to approximately 30 minutes of preparation and pipeline execution |
| **Reduced operational risk** | The process is no longer dependent on a single person's knowledge or the correct use of a specific Excel file |
| **Reliable audit trail** | Every run produces a complete, tamper-evident record without any additional analyst effort |
| **Consistent validation** | All four fund managers are checked using the same rules, every time, with no possibility of a check being skipped or applied inconsistently |
| **Safer data loading** | The pre-load quality gate means structurally invalid or incomplete data cannot reach ADS — the check that was previously manual and potentially skippable becomes a hard step |
| **Easier exception management** | When a lookup gap or validation failure occurs, the output reports identify exactly which rows are affected and why, so analysts know precisely what to investigate |
| **Scalable foundation** | Adding a fifth fund manager in the future requires a configuration update and a new ingestion notebook — not a redesign of the Excel workbook |
| **Faster exception investigation** | When a security or policy name can't be matched automatically, the AI fuzzy matcher suggests the most likely candidates from the master list — the analyst confirms rather than searches |
| **Proactive anomaly awareness** | Month-on-month portfolio movements that look statistically unusual are flagged automatically, rather than relying on an analyst to notice them in a table of numbers |
| **Run at a glance** | At the end of every run, the pipeline produces a plain-English paragraph summarising what happened, what passed, what failed, and what needs attention — no need to open multiple report files |

---

## What is out of scope for the PoC?

This PoC is deliberately focused. The following are noted as future enhancements rather than
deliverables for this phase:

- **Replacing Excel templates in production** — the PoC demonstrates capability; full
  production rollout is a separate workstream.
- **Automated sourcing of reference data** — FX rates, security master, and policy mapping are
  currently uploaded manually for the PoC; automated extraction from source systems is a
  follow-on.
- **Bank holiday calendars** — the staleness check uses a calendar-day approximation; a full
  bank holiday-aware calendar is a post-PoC enhancement.
- **Multi-period backfill** — the pipeline handles one month per run; bulk historical reprocessing
  is out of scope.
- **Real-time or intraday processing** — the pipeline is designed for monthly batch execution.

---

## How do we know it has worked?

The PoC is considered complete when the following outcomes are verified:

| # | What is checked |
|---|-----------------|
| 1 | Files from all four fund managers are ingested in a single run |
| 2 | Policy-level totals match the expected figures from the Excel reconciliation |
| 3 | All four validation rules produce results (including expected not-evaluable outcomes where data is absent) |
| 4 | Report files are written to the output folder and are readable |
| 5 | The reconciliation summary JSON shows non-zero GBP totals |
| 6 | Re-running the same period twice does not create duplicate data |
| 7 | Disabling one fund manager in the configuration does not affect the others |
| 8 | The run audit log has a complete row for every fund manager |
| 9 | The TPIR Upload Check shows a pass result after a clean run |
| 10 | ADS confirms the data load was committed and the audit log records the row count |

---

## What platform does it run on?

The pipeline runs entirely within the firm's existing **Microsoft Fabric** workspace, extended
with **Azure OpenAI** for the AI capabilities. Both run within the firm's Microsoft 365 and
Azure tenant — data does not leave the firm's environment. No new infrastructure is needed
beyond an active Fabric licence and an Azure OpenAI resource provisioned via a standard Azure
ARM template.

Data is stored in Fabric's secure OneLake storage. Access is controlled by the existing
workspace permissions — only the investment operations team and authorised technical staff can
access the data.

No credentials, passwords, or API keys are held in the pipeline code. All authenticated
connections (including the ADS load and the Azure OpenAI calls) use Azure Managed Identity,
which is a Microsoft-standard mechanism for secure service-to-service authentication.

**An important note on AI and data:** only DFM-level aggregate totals (e.g. “WH Ireland total
bid value £48.2m”) are sent to the Azure OpenAI service for anomaly analysis. Individual
policy positions, security names, and policy references do not leave Fabric for LLM processing.
The exception is the fuzzy matching step, which sends unresolved security/policy identifiers
(internal reference codes, not personal data) to the embedding API to find lookup matches.

---

## How is AI used in this PoC?

The PoC uses Azure OpenAI (GPT-4o and text-embedding-3-small) to augment the deterministic
pipeline at the points where rules-based logic cannot give the analyst a useful answer:

| Where AI helps | What it does | Why rules can’t do this |
|---|---|---|
| **When a fund manager changes their file layout** | Proposes a config update to re-map the new column names | Column name matching is ambiguous — “Settlement Ccy” and “CCY” are the same thing, but no rule knows that |
| **When a security or policy can’t be found** | Suggests the most likely match from the master list, ranked by confidence | Name variations like “Vodafone Grp PLC” vs “Vodafone Group PLC” cannot be deterministically matched |
| **After aggregation, every month** | Flags portfolio-level movements that look unusual vs prior months | Rules check individual rows; only AI has the cross-period context to say “that 40% drop looks unusual” |
| **After validation, if failures exist** | Classifies each failure as expected or new | The analyst should only have to read the *new* failures each month, not re-triage the same known patterns |
| **At the end of every run** | Writes a plain-English summary of what happened | The human reads one paragraph, not five separate report files |

**What AI does not do:** AI never modifies the holdings data, the validation rules, the
reconciliation totals, or the ADS load. All AI outputs are clearly labelled as AI-generated
and are advisory only. The analyst remains in control of all decisions.

---

## A note on how this PoC was built

This PoC was designed, specified, and documented using a GitHub Copilot agent fleet operating
from structured specifications stored in the repository. The agents produced specs, data
contracts, validation rules, runbooks, and this document — working from the requirements
described in the engineering spec folder. Human review was applied to all financial logic.

This means the PoC is not just *about* AI — it was *built using* AI as the primary engineering
assistant. The repository structure is intentionally agent-native: work is defined in `specs/`,
executed by agents declared in `agents/`, and verified against acceptance criteria in each
task block.

---

## What happens after the PoC?

If the PoC successfully demonstrates all outcomes above, the recommended next steps are:

1. **Production readiness review** — review access controls, alerting, and scheduling to meet
   production standards.
2. **ADS transport confirmation** — confirm the API-based loading approach with the ADS system
   owner and finalise any authentication or network connectivity requirements.
3. **Automated reference data sourcing** — connect `fx_rates.csv`, `security_master.csv`, and
   `policy_mapping.csv` to their source systems to remove the remaining manual preparation steps.
4. **Scheduling** — configure the Fabric Pipeline to trigger automatically on a defined schedule
   each month.
5. **Natural language reporting** — a forward-looking design for Microsoft Copilot Studio
   integration has been outlined, which would allow stakeholders to query reconciliation results
   using conversational questions rather than reviewing CSV files.

---

*This document is a summary for business stakeholders. The full technical design is in
[docs/DFM_PoC_Design.md](DFM_PoC_Design.md). The operational runbook for analysts is in
[docs/runbooks/analyst-period-workflow.md](runbooks/analyst-period-workflow.md).*
