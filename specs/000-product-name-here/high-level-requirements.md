# high-level-requirements.md

> **Template guidance:** Copy this file into `specs/00-product/high-level-requirements.md`.
>
> These requirements define **what the system must achieve**, independent of technology choices.
> Each requirement should later map to one or more features in `feature-map.md`.

## High Level Requirements

### HR-01 Capture

- **HR-01.1 Universal capture:** Capture the content types relevant to this product (e.g. text, images, screenshots, voice, links, files).
- **HR-01.2 Multi-platform:** Capture must be available on the target platforms: [list].
- **HR-01.3 Context preservation:** Store minimal context with every capture (timestamp, source, user notes, etc.).
- **HR-01.4 Offline-first where appropriate:** Capture must work without connectivity and sync later.

### HR-02 Organisation

- **HR-02.1 Action-oriented organisation:** Support organising around how users work (projects/areas/workstreams/cases), not only topics.
- **HR-02.2 Low friction:** Organisation actions should be optional and lightweight.
- **HR-02.3 Reusable building blocks:** Captures must remain reusable across future contexts.

### HR-03 Distillation

- **HR-03.1 Progressive refinement:** Support incremental summarisation/highlighting/annotation over time.
- **HR-03.2 Multi-layer views:** Allow viewing raw content vs distilled essence.
- **HR-03.3 Future-self optimisation:** Make content understandable when revisited later.

### HR-04 Expression / Output

- **HR-04.1 Reuse:** Enable assembling prior captures into outputs.
- **HR-04.2 Discovery-driven creativity:** Encourage connection-making and recombination.
- **HR-04.3 Incremental output:** Support iterative creation rather than big-bang documents.

### HR-05 Discovery and Interaction

- **HR-05.1 Search:** Keyword + filters (time, source, type, tags, etc.).
- **HR-05.2 Semantic retrieval:** Natural language queries and meaning-based ranking.
- **HR-05.3 Exploration:** Support browsing and “stumbling upon” relevant items.

### HR-06 Visual Knowledge Exploration (Optional)

- **HR-06.1 Relationship visualisation:** Provide a graph or relationship view where valuable.
- **HR-06.2 Interaction:** Navigate connections, filter, and drill into items.

### HR-07 Data & Platform Foundations

- **HR-07.1 Unified data model:** Represent artefacts, metadata, relationships, and derived summaries consistently.
- **HR-07.2 Durable storage:** Persist artefacts and metadata reliably.
- **HR-07.3 Synchronisation:** Sync across devices with conflict resilience.

### HR-08 Security, Privacy, and Trust

- **HR-08.1 Ownership:** Users control their data and exports.
- **HR-08.2 Protection:** Encryption at rest/in transit; access control; secret management.
- **HR-08.3 Safety by default:** Scanning and threat modelling where relevant.

### HR-09 Quality Attributes (Non-functional)

- **HR-09.1 Performance:** Capture feels instant; retrieval is fast enough for flow.
- **HR-09.2 Scalability:** Handles growth from small to large datasets.
- **HR-09.3 Extensibility:** Supports new platforms/content types over time.
- **HR-09.4 Maintainability:** Modular design supports feature-based evolution.

## Requirement Ownership (Agent Guidance)

> **Template:** Update the mapping to match your agent registry.

- Orchestrator: triage and sequencing
- Architecture: boundaries, trade-offs, ADRs
- App agents: UI/API feature delivery
- Data/Analytics: model, search, graph
- UX/Design: capture UX, exploration UX
- Security: privacy, threat model, CI gates

