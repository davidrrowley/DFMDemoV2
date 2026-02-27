# Architecture: Knowledge Capture and Reuse Platform

> **Scope:** System boundaries, key components, and design principles.
> Individual feature specs (specs/F**/spec.md) detail component behaviour.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Environments                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │   Mobile     │  │   Desktop    │  │   Web UI     │           │
│  │  (Android)   │  │  (macOS/Win) │  │ (Carbon/TS)  │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                            ↓ (APIs)
┌─────────────────────────────────────────────────────────────────┐
│                  Ingestion & Storage API                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  OpenAPI Contract: /captures, /metadata, /sync, /search   │ │
│  │  Authentication: OAuth 2.0 / Device tokens                │ │
│  │  Versioning: Stable v1.x with deprecation policy          │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Backend Services (API)                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Ingestion Service    (handle uploads, validate, queue)   │ │
│  │  Metadata Service     (store, index, search, sync)        │ │
│  │  Blob Service         (durable artefact storage)          │ │
│  │  Sync Service         (conflict resolution, versioning)   │ │
│  │  Search Service       (keyword + semantic indexing)       │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Storage Layer (Persistence)                    │
│  ┌──────────────────────┐  ┌──────────────────────┐           │
│  │  Metadata Store      │  │  Blob Storage        │           │
│  │  (CosmosDB/RDB)      │  │  (Azure Blob/S3)     │           │
│  │  • Metadata          │  │  • Media files       │           │
│  │  • Relationships     │  │  • Backups           │           │
│  │  • Search indices    │  │                      │           │
│  └──────────────────────┘  └──────────────────────┘           │
│  ┌──────────────────────┐                                      │
│  │  Cache (optional)    │  (Redis/Memcached for perf)         │
│  └──────────────────────┘                                      │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

### Clients (Capture & Sync)

**Platform-specific implementations:** Android, Fluent UI (Windows), Carbon (Web), macOS.

**Capabilities:**
- Offline-first capture (local queue, retry logic)
- Sync with conflict resolution (last-write-wins or merge strategies per field)
- Background upload of queued items
- Local caching for performance

**Contracts:**
- Sync API (pull/push deltas)
- Ingestion API (POST /captures)
- Search API (GET /search)

---

### Ingestion API

**Purpose:** Stable boundary between clients and backend.

**Contract:**
- **POST /captures** — Accept media file + metadata, queue for processing
- **POST /metadata** — Enrich or update metadata
- **GET /sync** — Pull outbound changes since last sync
- **POST /sync** — Push device changes for sync
- **DELETE /captures/{id}** — Soft delete or tombstone

**Design principles:**
- Contract-first (OpenAPI document is canonical)
- Idempotent uploads (correlationId, idempotencyKey)
- Rate limiting and backpressure
- Versioning with deprecation windows

---

### Metadata Service

**Purpose:** Unified store for user knowledge.

**Entities:**
- **MediaItem:** The captured content (image, file, link, note)
- **Metadata:** Context (tags, project, source, capturedAt, etc.)
- **Relationships:** Connections between items (references, threads)
- **Annotations:** User refinements (highlights, notes, summaries)

**Capabilities:**
- CRUD operations with conflict-safe merging
- Full-text search + semantic indexing
- Filtering by type, date, tag, project
- Relationship queries (graph traversal)

---

### Blob Storage

**Purpose:** Durable, scalable artefact storage.

**Design:**
- Immutable once written (object versioning for safety)
- Encryption at rest
- Tiered storage (hot → cool → archive) based on access patterns
- Deduplication by content hash (same file uploaded from multiple devices)

---

### Sync Service

**Purpose:** Keep user's devices in lockstep.

**Strategy:**
- Last-write-wins for simple fields (tags, timestamps)
- Merge strategies for rich fields (metadata, annotations)
- Tombstone approach for deletions (safe distributed delete)
- Eventual consistency model (microseconds to seconds)

---

## Design Principles

### 1. Offline-First
- Clients queue captures locally; sync when connectivity returns.
- No loss of data due to network transience.
- Graceful degradation when backend is unreachable.

### 2. Contract-First
- OpenAPI specifications before implementation.
- Stable API versioning; deprecated endpoints have 12-month runways.

### 3. Durable by Default
- Metadata replicated; blob storage has geographic redundancy.
- Audit log of all mutations for compliance.
- User data exportable in open formats.

### 4. Search-Optimized
- All metadata indexed for full-text search.
- Embeddings computed off-line (optional, for semantic search in Wave 02).
- Index fast; rebuild if necessary (no single point of failure).

### 5. Efficient & Scalable
- Pagination for large result sets.
- Lazy loading of rich fields (metadata, annotations).
- Cache frequently accessed artefacts.

### 6. Secure by Default
- Encryption in transit (TLS) and at rest (keys managed by platform).
- Authentication via OAuth 2.0 (future: SAML for enterprise).
- Access control: Users see only their own data.
- Threat model maintained in `security-baseline.md`.

---

## Technology Stack (Sample)

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Mobile (Android)** | Kotlin + Room (local), Retrofit (API) | Native performance, offline-first |
| **Desktop (Windows/Mac)** | Fluent UI / SwiftUI / Electron | Platform-native UX |
| **Web** | React + TypeScript (Carbon components) | UX consistency, type safety |
| **API Gateway** | API Management (Azure APIM) | Rate limiting, versioning, analytics |
| **Metadata Storage** | CosmosDB or PostgreSQL | Rich queries, graph-like relationships |
| **Blob Storage** | Azure Blob Storage or S3 | Durability, cost-effective at scale |
| **Search** | Azure Search or Elasticsearch | Full-text + semantic search |
| **Sync** | Custom or CouchDB-style | Eventual consistency, conflict resolution |
| **Cache** | Redis | Performance, session state |
| **CI/CD** | GitHub Actions / Azure Pipelines | Integration with spec-kit agents |

---

## Deployment Topology

- **Development:** Localhost with Docker Compose
- **Staging:** Single-region deployment with representative data
- **Production:** Multi-region with geo-failover, DDoS protection, WAF

---

## Data Model

See [data-model.md](data-model.md) for entity definitions, relationships, and validation rules.

---

## Security & Compliance

See [security-baseline.md](security-baseline.md) for threat model, mitigations, and controls.

---

## See Also

- [product-vision.md](product-vision.md) — What problem this solves
- [high-level-requirements.md](high-level-requirements.md) — Functional and NFR
- [feature-map.md](feature-map.md) — Features mapped to components
- [roadmap.md](roadmap.md) — Sequencing of features and components
