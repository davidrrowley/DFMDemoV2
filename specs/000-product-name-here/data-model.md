# Data Model: Offline Media Capture and Upload

## Entities

### MediaItem

**Represents**: A captured or selected media file stored locally.

**Fields**:
- `mediaItemId` (string, required): Local UUID for the file.
- `localPath` (string, required): App data path to the media file.
- `previewPath` (string, optional): Path to a generated preview image.
- `mediaType` (string, required): `image`, `video`, or `audio`.
- `contentType` (string, required): MIME type.
- `contentLength` (number, required): Size in bytes.
- `contentHash` (string, required): SHA-256 hash for idempotency.
- `capturedAt` (datetime, required): Capture or selection timestamp.
- `originalFilename` (string, optional): Original file name when selected.

**Validation**:
- `localPath`, `mediaType`, `contentType`, `contentLength`, `contentHash` required.
- `contentLength` must be > 0.

### UploadQueueEntry

**Represents**: A queued upload attempt and its current state.

**Fields**:
- `queueEntryId` (string, required): Local UUID for the queue entry.
- `mediaItemId` (string, required): Reference to MediaItem.
- `status` (string, required): `pending`, `uploading`, `uploaded`, `failed`.
- `attemptCount` (number, required): Total attempts.
- `nextAttemptAt` (datetime, optional): Scheduled retry time.
- `lastAttemptAt` (datetime, optional): Timestamp of last attempt.
- `correlationId` (string, required): Per-upload correlation ID.
- `idempotencyKey` (string, required): Stable key for retry safety.
- `blobName` (string, optional): Target blob name.
- `blobUri` (string, optional): Target blob URI.
- `blobETag` (string, optional): ETag from upload.
- `cosmosId` (string, optional): Metadata document `id`.
- `errorCode` (string, optional): Last error code.
- `errorMessage` (string, optional): Last error message (redacted).

**Validation**:
- `mediaItemId`, `status`, `correlationId`, `idempotencyKey` required.
- `attemptCount` must be >= 0.

**State Transitions**:
- `pending` -> `uploading`
- `uploading` -> `uploaded`
- `uploading` -> `failed`
- `failed` -> `uploading` (retry)

### MetadataRecord (Cosmos DB)

**Represents**: Server-side metadata for uploaded media.

**Fields**:
- `id` (string, required): Deterministic id (idempotency key or derived).
- `partitionKey` (string, required): `deviceId` (or `userId` if auth is added).
- `idempotencyKey` (string, required): Stable key for retry safety.
- `deviceId` (string, required): Device identifier.
- `correlationId` (string, required): Per-upload correlation ID.
- `contentType` (string, required)
- `contentLength` (number, required)
- `contentHash` (string, required)
- `blobContainer` (string, required)
- `blobName` (string, required)
- `blobUri` (string, required)
- `blobETag` (string, optional)
- `status` (string, required): `pending`, `uploaded`, `failed`.
- `capturedAt` (datetime, required)
- `createdAt` (datetime, required)
- `completedAt` (datetime, optional)
- `originalFilename` (string, optional)

**Validation**:
- Required fields must be present for `uploaded` status: `blobUri`, `blobName`, `contentHash`, `contentLength`.
- `id` and `partitionKey` required for all writes.

## Relationships

- `UploadQueueEntry.mediaItemId` -> `MediaItem.mediaItemId`
- `MetadataRecord` references `UploadQueueEntry.idempotencyKey` and `MediaItem` content details
