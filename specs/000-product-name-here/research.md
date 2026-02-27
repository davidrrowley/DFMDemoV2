# Research: Offline Media Capture and Upload

> **⚠️ Note:** This file has moved to [specs/001-feature-name-here/research.md](../001-feature-name-here/research.md).
> This product folder contains product-level specifications; feature research belongs in feature folders.
>
> See [specs/README.md](../README.md) for the correct structure.

---

## Offline-first capture and queue

- **Decision**: Store captured media files in app data storage and persist queue metadata in SQLite; use connectivity change events plus app resume to trigger retries with exponential backoff.
- **Rationale**: App data storage is durable across restarts; SQLite provides structured queue state and retry scheduling; connectivity events are hints, not guarantees.
- **Alternatives considered**: Cache storage (can be evicted by OS), Preferences (too small for queue state), immediate network-only uploads (fails offline).

## Idempotent upload design

- **Decision**: Use a deterministic idempotency key to derive blob name and Cosmos `id`, use conditional blob creates (`If-None-Match: *`), and Cosmos unique key policy on `idempotencyKey`.
- **Rationale**: Deterministic identifiers and conditional writes make retries safe and prevent duplicate metadata or blobs.
- **Alternatives considered**: Random blob names with duplicate cleanup (complex), server-only dedupe (requires extra services), storing binaries in Cosmos (cost/size constraint).

## Secure-by-default configuration

- **Decision**: Keep `appsettings.json` for non-secret defaults only, use environment variables for local desktop dev, and store tokens in SecureStorage on device.
- **Rationale**: App packages are public; SecureStorage is the only acceptable place for device secrets; environment variables are not reliable on mobile devices.
- **Alternatives considered**: Embedding API keys in appsettings or code (violates security), storing tokens in Preferences or files (insecure).

## Upload completion confirmation

- **Decision**: Mark an item successful only after blob upload and Cosmos metadata write both succeed; persist correlation ID and blob ETag for diagnostics.
- **Rationale**: Prevents partial success from being shown as complete and supports idempotent retry logic.
- **Alternatives considered**: Optimistic completion on blob success only (metadata drift), immediate delete of local record (risk of data loss).
