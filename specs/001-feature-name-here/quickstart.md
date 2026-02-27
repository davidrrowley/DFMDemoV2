# Quickstart: Offline Media Capture and Upload

## Prerequisites

- .NET 8 SDK
- .NET MAUI workloads
- Azure Storage account with a blob container
- Azure Cosmos DB account and database/collection for metadata

## Configuration

1. Create `appsettings.json` with non-secret defaults (example keys):

```json
{
  "Storage": {
    "ContainerName": "media"
  },
  "Cosmos": {
    "Database": "cortexyou",
    "Container": "media-metadata",
    "PartitionKeyPath": "/partitionKey"
  }
}
```

2. Provide credentials via secure channels:

- Windows dev: environment variables or user secrets for local testing
- Android device: SecureStorage after auth

3. Do not place secrets in source control.

## Local Development Flow

1. Build the app and launch on Windows.
2. Capture or select media while offline; confirm it appears in the local queue.
3. Restore connectivity and upload; confirm success is shown only after both blob and metadata writes.

## Tests

- Unit tests: queue persistence, retry scheduling, idempotency behavior
- Integration tests: Cosmos + Blob writes in a dev environment

## Troubleshooting

- If uploads fail repeatedly, verify network access and storage credentials.
- If metadata writes fail, verify Cosmos `partitionKey` and required `id` values.
