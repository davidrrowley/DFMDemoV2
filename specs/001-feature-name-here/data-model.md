# Data Model: Offline Media Capture and Upload

> **Note:** Feature-level data model entities are defined at the product level.
> See [specs/000-product-name-here/data-model.md](../000-product-name-here/data-model.md) for the canonical entity definitions.

This feature implements the entities and state machines defined in the product data model:
- **MediaItem** — Local capture representation
- **UploadQueueEntry** — Upload state management and retry logic
- **MetadataRecord** — Server-side metadata persistence

## Feature-Specific Implementation Notes

### Local Storage Schema (Device)

For offline-first capture on mobile/desktop:

```
Database: app.db (SQLite, encrypted)

Table: media_items
- mediaItemId (TEXT, PK)
- localPath (TEXT NOT NULL)
- previewPath (TEXT)
- mediaType (TEXT NOT NULL) → image|video|audio
- contentType (TEXT NOT NULL)
- contentLength (INTEGER NOT NULL)
- contentHash (TEXT NOT NULL)
- capturedAt (DATETIME NOT NULL)
- originalFilename (TEXT)
- createdAt (DATETIME DEFAULT NOW())
- syncedAt (DATETIME)

Table: upload_queue
- queueEntryId (TEXT, PK)
- mediaItemId (TEXT, FK → media_items)
- status (TEXT NOT NULL) → pending|uploading|uploaded|failed
- attemptCount (INTEGER >= 0)
- nextAttemptAt (DATETIME)
- lastAttemptAt (DATETIME)
- correlationId (TEXT NOT NULL)
- idempotencyKey (TEXT NOT NULL, UNIQUE)
- blobName (TEXT)
- blobUri (TEXT)
- blobETag (TEXT)
- cosmosId (TEXT)
- errorCode (TEXT)
- errorMessage (TEXT)
- createdAt (DATETIME DEFAULT NOW())
```

### State Machine: UploadQueueEntry

```
          ┌─────────┐
          │ pending │
          └────┬────┘
               │ (device online, start upload)
               ↓
          ┌─────────────┐
     ┌────→│  uploading  │────┐
     │    └─────────────┘     │
     │                        │
  (retry)                  (success)
     │                        │
     │                        ↓
     │                  ┌──────────┐
     │                  │ uploaded │
     │                  └──────────┘
     │                        ↑
     │                    (sync ACK)
     │
  (failure after max retries: 10)
     │
     └────→ ┌────────┐
            │ failed │ (manual retry or deletion)
            └────────┘
```

### Conflict Resolution

When device syncs after offline period:
1. If `uploaded` status + ACK received → assume success, advance to `synced`
2. If `uploading` status + timer exceeded → assume transient failure, retry
3. If `failed` status → wait for user action (manual retry) or garbage collection (30 days)

---

## See Also

- [Product Data Model](../000-product-name-here/data-model.md) — Canonical entity definitions and relationships
- [spec.md](spec.md) — Feature requirements and acceptance criteria
- [Architecture](../000-product-name-here/architecture.md) — System-level storage and sync patterns
