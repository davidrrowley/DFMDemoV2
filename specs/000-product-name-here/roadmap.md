# Roadmap: Knowledge Capture and Reuse Platform

> **Purpose:** Sequencing and timeline for feature delivery.
> Each wave delivers independent value; waves can be refined based on user feedback.

## Wave 01: Foundations – Universal Capture & Sync

**Goal:** Enable users to reliably capture content from any device, sync across devices, and trust durability.

**Target features:**
- F01: Offline-first media capture (images, files, voice)
- F02: Ingestion API (stable contract for all clients)
- F03: Storage & cross-device sync

**Why first:** Without reliable capture and sync, no upstream capability (search, org, distill) has value. Foundations must be solid. Ship a thin, high-quality experience.

**User value:** "I can capture anywhere, offline, and it's safe."

**Dependency:** None (foundations)

**Estimated timeline:** T+0 to T+8 weeks

---

## Wave 02: Discovery & Organisation – Making Knowledge Findable

**Goal:** Help users **rediscover** content and organise it for reuse.

**Target features:**
- F04: Keyword search + filters (time, type, source)
- F05: Low-friction organisation (tags, projects, collections)
- F06: Semantic search (NL queries, meaning-based ranking) — *optional for early wave*

**Why second:** Only makes sense when users have accumulated meaningful collections. Completes the "capture → store → find" loop.

**User value:** "I can find what I captured, even months later."

**Dependency:** Wave 01 (storage, metadata)

**Estimated timeline:** T+8 to T+14 weeks

---

## Wave 03: Distillation & Expression – Creating from Knowledge

**Goal:** Enable users to **refine, annotate, and assemble** knowledge into outputs.

**Target features:**
- F07: Progressive annotation (highlights, notes, summaries)
- F08: Multi-layer views (raw → distilled)
- F09: Output assembly (documents, reports, exports)

**Why third:** Enables "move from consumption to creation" without building a document editor. Leverages stored metadata.

**User value:** "My captures become building blocks for new work."

**Dependency:** Wave 02 (search, organisation)

**Estimated timeline:** T+14 to T+20 weeks

---

## Wave 04: Insight & Exploration – Seeing Connections

**Goal:** Make relationships visible and enable *serendipitous discovery*.

**Target features:**
- F10: Relationship visualisation (graph, timelines)
- F11: Exploration UI (browsing, stumbling upon insights)
- F12: Advanced analytics (insights, trends, clusters) — *optional*

**Why fourth:** Builds on critical mass of tagged, annotated, cross-referenced items. Highest value when dataset is mature.

**User value:** "I see connections I didn't know existed in my knowledge."

**Dependency:** Wave 03 (annotation, metadata richness)

**Estimated timeline:** T+20 to T+26 weeks

---

## Wave 05 & Beyond: Extensibility & Intelligence

**Future capabilities** (post-MVP):
- Deep NLP (auto-summarisation, entity extraction, topic modelling)
- Integration marketplace (Zapier, Make, IFTTT connectors)
- Real-time collaboration features
- Advanced privacy controls (sharing, access grants, audit logs)
- Mobile and platform-specific native optimisations

---

## Release Milestones

| Milestone | Features | Target Date |
|-----------|----------|-------------|
| **MVP** | Wave 01 (capture, sync) | T+8w |
| **v1.1** | Wave 02 (search, org) | T+14w |
| **v1.2** | Wave 03 (distill, output) | T+20w |
| **v2.0** | Wave 04 (graph, exploration) | T+26w |
| **v2.1+** | Advanced features | T+32w+ |

---

## Key Sequencing Rules

1. **Ship value early:** Each wave delivers independent user value; don't gate on later waves.
2. **Foundation quality:** Capture and sync must be exceptionally reliable; future features depend on it.
3. **Feedback loops:** Use Wave 01 adoption to validate assumptions before investing in Waves 02+.
4. **Parallel streams:** UI, API, and data teams can work in parallel within waves (see `feature-map.md` and `agent-execution-model.md`).

---

## See Also

- [feature-map.md](feature-map.md) — Individual feature ownership and boundaries
- [architecture.md](architecture.md) — System design supporting this sequencing
- [high-level-requirements.md](high-level-requirements.md) — Requirements mapped to features and waves
