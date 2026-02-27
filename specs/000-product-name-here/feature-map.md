# feature-map.md

> **Template guidance:** Copy this file into `specs/00-product/feature-map.md`.
>
> This maps requirements → features and establishes **clear feature boundaries** and **default agent ownership**.

## How to Use This File

1. Start from `high-level-requirements.md`.
2. Create a feature for each coherent capability boundary.
3. Map each feature to the requirements it satisfies.
4. Assign a default owner (agent id) and required reviewers.
5. Create one folder per feature under `specs/` containing `spec.md`, `plan.md`, and `tasks.md`.

## Feature Catalogue

> Replace the examples below with your product’s feature set.

### F01 – Capture Clients (by platform)

**Purpose:** Provide low-friction capture experiences on each target platform.

**Satisfies:** HR-01, HR-09.1  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  
**Notes:** Keep capture “thin” — send through ingestion API.

---

### F02 – Ingestion API

**Purpose:** Stable boundary between clients and storage.

**Satisfies:** HR-01.3, HR-07.3  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  
**Notes:** Contract-first (OpenAPI) recommended.

---

### F03 – Storage & Sync

**Purpose:** Durable artefact storage, metadata persistence, and cross-device sync.

**Satisfies:** HR-07.2, HR-07.3, HR-08  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  

---

### F04 – Knowledge/Metadata Model

**Purpose:** Unified representation for artefacts, metadata, relationships, and derived summaries.

**Satisfies:** HR-07.1  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  

---

### F05 – Organisation Layer

**Purpose:** Low-friction organisation aligned to how users work.

**Satisfies:** HR-02  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  

---

### F06 – Distillation

**Purpose:** Progressive refinement of captured items.

**Satisfies:** HR-03  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  

---

### F07 – Search & Natural Language Discovery

**Purpose:** Keyword and semantic retrieval, natural language queries.

**Satisfies:** HR-05  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  

---

### F08 – Visual Exploration (Graph) (Optional)

**Purpose:** Visualise and navigate relationships.

**Satisfies:** HR-06  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  

---

### F09 – Web App / Primary Experience

**Purpose:** Main surface for browsing, editing, linking, and composing.

**Satisfies:** HR-04, HR-05  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  

---

### F10 – Export / Output Tools

**Purpose:** Enable users to produce outputs (docs, bundles, shares).

**Satisfies:** HR-04  
**Default owner:** [agent-id]  
**Reviewers:** [agent-ids]  

---

## Feature Boundary Rules (Template)

- Clients do not write directly to storage; they call the ingestion API.
- UI does not own core data modelling; changes require architecture review.
- AI/enrichment writes derived artefacts separately; it must not silently overwrite user-authored content.
- Schema changes require an ADR and a migration plan.

## Dependencies (Template)

Define dependency waves to enable parallel delivery:

- Wave 1: foundations (infra, identity, ingestion API, data model)
- Wave 2: core experiences (capture clients, web shell)
- Wave 3: advanced (search, graph, enrichment, export)

