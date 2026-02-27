# Implementation Plan: Offline Media Capture and Upload

> **⚠️ Note:** This file has moved to [specs/001-feature-name-here/plan.md](../001-feature-name-here/plan.md).
> This product folder contains product-level specifications; feature plans belong in feature folders.
>
> See [specs/README.md](../README.md) for the correct structure.

---

**Branch**: `001-offline-media-upload` | **Date**: February 15, 2026 | **Spec**: [specs/001-offline-media-upload/spec.md](specs/001-offline-media-upload/spec.md)
**Input**: Feature specification from `/specs/001-offline-media-upload/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deliver an offline-first .NET MAUI flow that captures or selects media, stores it locally with a queued upload record, then uploads binaries to Azure Blob Storage and metadata to Cosmos DB with idempotent retries and secure configuration.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: C# with .NET 8 (.NET MAUI)  
**Primary Dependencies**: .NET MAUI, Azure.Storage.Blobs, Microsoft.Azure.Cosmos, sqlite-net-pcl (local queue), Polly (retry/backoff)  
**Storage**: Local app data files + SQLite for queue; Azure Blob Storage for binaries; Cosmos DB for metadata  
**Testing**: xUnit for unit tests; integration tests against dev Cosmos + Blob  
**Target Platform**: Windows 10/11 and Android 10+  
**Project Type**: mobile (single MAUI app with shared core library)  
**Performance Goals**: Preview within 3 seconds for 95% of captures; queued uploads succeed within 5 minutes of connectivity restoration  
**Constraints**: Offline-first, idempotent uploads, no secrets in source control, cross-platform APIs only  
**Scale/Scope**: Single-user device capture with a local queue (dozens to hundreds of items)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- No project constitution rules are defined in [.specify/memory/constitution.md](.specify/memory/constitution.md) (template only). No additional gates apply.
- Note: Constitution content should be defined if project-level gates are required.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
src/
├── CortexYou.App/           # .NET MAUI app (UI + platform projects)
└── CortexYou.Core/          # Shared models, queue, upload orchestration

tests/
├── CortexYou.Core.Tests/    # Unit tests for queue and upload orchestration
└── CortexYou.IntegrationTests/ # Dev Cosmos + Blob integration tests
```

**Structure Decision**: Single MAUI app with a shared core library to keep business logic testable and cross-platform.

## Constitution Check (Post-Design)

- No additional constitution gates apply; post-design check passes.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
