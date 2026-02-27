---

description: "Task list for Offline Media Capture and Upload"
---

# Tasks: Offline Media Capture and Upload

> **⚠️ Note:** This file has moved to [specs/001-feature-name-here/tasks.md](../001-feature-name-here/tasks.md).
> This product folder contains product-level specifications; feature task lists belong in feature folders.
>
> See [specs/README.md](../README.md) for the correct structure.

---

**Input**: Design documents from `/specs/001-feature-name-here/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Included because the spec requires unit tests for upload orchestration and queue behavior plus an integration test for Cosmos + Blob.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create solution file in src/CortexYou.sln
- [ ] T002 Create MAUI app project in src/CortexYou.App/CortexYou.App.csproj
- [ ] T003 Create core library project in src/CortexYou.Core/CortexYou.Core.csproj
- [ ] T004 Create unit test project in tests/CortexYou.Core.Tests/CortexYou.Core.Tests.csproj
- [ ] T005 Create integration test project in tests/CortexYou.IntegrationTests/CortexYou.IntegrationTests.csproj
- [ ] T006 [P] Add MAUI app settings file at src/CortexYou.App/appsettings.json (non-secret defaults only)
- [ ] T007 [P] Add solution-level README for local dev at src/README.md
- [ ] T044 [P] Add NuGet dependencies to src/CortexYou.App/CortexYou.App.csproj and src/CortexYou.Core/CortexYou.Core.csproj (Azure.Storage.Blobs, Microsoft.Azure.Cosmos, sqlite-net-pcl, Polly)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**Checkpoint**: Foundation ready - user story implementation can now begin

- [ ] T008 Create shared models for queue and metadata in src/CortexYou.Core/Models/MediaItem.cs and src/CortexYou.Core/Models/UploadQueueEntry.cs
- [ ] T009 Create local storage abstractions in src/CortexYou.Core/Storage/ILocalMediaStore.cs and src/CortexYou.Core/Storage/IQueueStore.cs
- [ ] T010 Implement SQLite queue store in src/CortexYou.Core/Storage/SqliteQueueStore.cs
- [ ] T011 Implement local media storage in src/CortexYou.Core/Storage/LocalMediaStore.cs
- [ ] T012 Create idempotency key generator in src/CortexYou.Core/Uploads/IdempotencyKeyGenerator.cs
- [ ] T013 Create connectivity service in src/CortexYou.Core/Networking/ConnectivityService.cs
- [ ] T014 Create retry policy wrapper in src/CortexYou.Core/Uploads/RetryPolicyFactory.cs
- [ ] T015 Create Azure clients wrapper in src/CortexYou.Core/Uploads/AzureClientFactory.cs
- [ ] T016 Create upload orchestrator interface in src/CortexYou.Core/Uploads/IUploadOrchestrator.cs
- [ ] T017 Implement configuration binding in src/CortexYou.App/Configuration/AppConfiguration.cs
- [ ] T018 Wire dependency injection in src/CortexYou.App/MauiProgram.cs
- [ ] T019 Add structured logging helpers in src/CortexYou.Core/Logging/UploadLogger.cs
- [ ] T045 Add correlation ID propagation to upload pipeline in src/CortexYou.Core/Uploads/UploadOrchestrator.cs and src/CortexYou.Core/Logging/UploadLogger.cs
- [ ] T046 Implement SecureStorage credential handling in src/CortexYou.App/Configuration/SecureStorageConfig.cs and src/CortexYou.App/Services/CredentialProvider.cs

---

## Phase 3: User Story 1 - Capture or Select Media Offline (Priority: P1) \ud83c\udfaf MVP

**Goal**: Capture or select media, show a preview, and create a pending upload entry while offline.

**Independent Test**: Disable network, capture or select media, and verify preview plus a pending queue entry in local storage.

### Tests for User Story 1

- [ ] T020 [P] [US1] Add unit tests for queue persistence in tests/CortexYou.Core.Tests/QueueStoreTests.cs
- [ ] T021 [P] [US1] Add unit tests for idempotency key generation in tests/CortexYou.Core.Tests/IdempotencyKeyTests.cs

### Implementation for User Story 1

- [ ] T022 [P] [US1] Implement capture UI in src/CortexYou.App/Views/CapturePage.xaml and src/CortexYou.App/Views/CapturePage.xaml.cs
- [ ] T023 [P] [US1] Implement media picker UI in src/CortexYou.App/Views/SelectPage.xaml and src/CortexYou.App/Views/SelectPage.xaml.cs
- [ ] T024 [US1] Add preview view model in src/CortexYou.App/ViewModels/PreviewViewModel.cs
- [ ] T025 [US1] Implement media import service in src/CortexYou.Core/Media/MediaImportService.cs
- [ ] T026 [US1] Save media file locally in src/CortexYou.Core/Storage/LocalMediaStore.cs
- [ ] T027 [US1] Create pending queue entry in src/CortexYou.Core/Storage/SqliteQueueStore.cs
- [ ] T028 [US1] Add pending items list UI in src/CortexYou.App/Views/QueuePage.xaml and src/CortexYou.App/Views/QueuePage.xaml.cs

**Checkpoint**: User Story 1 is fully functional and testable independently.

---

## Phase 4: User Story 2 - Upload From Queue When Online (Priority: P2)

**Goal**: Upload pending items to Blob Storage and metadata to Cosmos DB, then show confirmation.

**Independent Test**: Queue an item offline, restore connectivity, upload, and verify item appears in Cosmos with a required `id`.

### Tests for User Story 2

- [ ] T029 [P] [US2] Add unit tests for upload orchestration in tests/CortexYou.Core.Tests/UploadOrchestratorTests.cs
- [ ] T030 [P] [US2] Add integration test for Cosmos + Blob writes in tests/CortexYou.IntegrationTests/CosmosBlobIntegrationTests.cs

### Implementation for User Story 2

- [ ] T031 [US2] Implement upload orchestrator in src/CortexYou.Core/Uploads/UploadOrchestrator.cs
- [ ] T032 [US2] Implement blob upload with conditional create in src/CortexYou.Core/Uploads/BlobUploadService.cs
- [ ] T033 [US2] Implement Cosmos metadata writer in src/CortexYou.Core/Uploads/CosmosMetadataService.cs
- [ ] T034 [US2] Add upload action and status binding in src/CortexYou.App/ViewModels/QueueViewModel.cs
- [ ] T035 [US2] Show upload success confirmation in src/CortexYou.App/Views/QueuePage.xaml and src/CortexYou.App/Views/QueuePage.xaml.cs

**Checkpoint**: User Stories 1 and 2 work independently; uploads succeed and metadata is written.

---

## Phase 5: User Story 3 - Automatic Retry Without Data Loss (Priority: P3)

**Goal**: Automatically retry failed uploads when connectivity is restored without duplicating records.

**Independent Test**: Force an upload failure, restore connectivity, and verify the queued item retries and succeeds without duplicates.

### Tests for User Story 3

- [ ] T036 [P] [US3] Add unit tests for retry scheduling in tests/CortexYou.Core.Tests/RetrySchedulerTests.cs

### Implementation for User Story 3

- [ ] T037 [US3] Implement retry scheduler in src/CortexYou.Core/Uploads/RetryScheduler.cs
- [ ] T038 [US3] Implement connectivity-triggered retries in src/CortexYou.App/Services/ConnectivityUploadService.cs
- [ ] T039 [US3] Persist retry state updates in src/CortexYou.Core/Storage/SqliteQueueStore.cs

**Checkpoint**: All user stories are independently functional with reliable retries.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T040 [P] Update quickstart with build and run steps in specs/001-offline-media-upload/quickstart.md
- [ ] T041 [P] Add CI build checks for Windows and Android in .github/workflows/ci.yml
- [ ] T042 Add log redaction guidelines in src/CortexYou.Core/Logging/UploadLogger.cs
- [ ] T043 Run quickstart validation steps in specs/001-offline-media-upload/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2)
- **User Story 2 (P2)**: Can start after Foundational (Phase 2)
- **User Story 3 (P3)**: Can start after Foundational (Phase 2)

### Parallel Opportunities

- Setup tasks T002-T005 can run in parallel
- Foundational tasks T008-T015 can run in parallel once T001-T003 complete
- Tests per user story are parallelizable with model and service work

---

## Parallel Example: User Story 1

```bash
Task: "Add unit tests for queue persistence in tests/CortexYou.Core.Tests/QueueStoreTests.cs"
Task: "Add unit tests for idempotency key generation in tests/CortexYou.Core.Tests/IdempotencyKeyTests.cs"
Task: "Implement capture UI in src/CortexYou.App/Views/CapturePage.xaml and src/CortexYou.App/Views/CapturePage.xaml.cs"
Task: "Implement media picker UI in src/CortexYou.App/Views/SelectPage.xaml and src/CortexYou.App/Views/SelectPage.xaml.cs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (blocks all stories)
3. Complete Phase 3: User Story 1
4. Validate User Story 1 independently

### Incremental Delivery

1. Setup + Foundational
2. User Story 1 \u2192 validate
3. User Story 2 \u2192 validate
4. User Story 3 \u2192 validate
5. Polish and CI hardening
