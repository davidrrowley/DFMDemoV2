# CI/CD runbook

## Philosophy
CI exists to enforce the quality bar described in `.specify/memory/constitution.md`.

## Minimum pipeline
- build
- test
- lint
- security scanning (dependency + SAST)

## Release
Release steps are documented in `.github/workflows/release.yml` and must be reproducible.
