# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\scaffold.ps1

$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$Manifest = Join-Path $RootDir "scripts\scaffold.manifest.txt"
$RepoName = Split-Path $RootDir -Leaf

function Ensure-File([string]$RelativePath) {
  $full = Join-Path $RootDir $RelativePath
  if (Test-Path $full) { return }
  $parent = Split-Path $full -Parent
  if (!(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
"" | Set-Content -Path $full -Encoding UTF8
}

function Write-IfMissing([string]$RelativePath,[string]$Content) {
  $full = Join-Path $RootDir $RelativePath
  if (Test-Path $full) { return }
  $parent = Split-Path $full -Parent
  if (!(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
  $Content | Set-Content -Path $full -Encoding UTF8
}

function Apply-Manifest {
  if (!(Test-Path $Manifest)) { throw "Manifest not found: $Manifest" }
  Get-Content $Manifest | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith("#")) { return }
    $parts = $line.Split(" ",2)
    $type = $parts[0]
    $path = $parts[1]
    $full = Join-Path $RootDir $path
    if ($type -eq "D") {
      if (!(Test-Path $full)) { New-Item -ItemType Directory -Path $full | Out-Null }
    } elseif ($type -eq "F") {
      Ensure-File $path
    } else {
      throw "Unknown manifest entry: $line"
    }
  }
}

function Hydrate {
  Write-IfMissing "README.md" @"
# $RepoName

Personal baseline template scaffold.

## Quick start
Run:
powershell -ExecutionPolicy Bypass -File .\scripts\scaffold.ps1
"@

  Write-IfMissing ".env.example" @"
APP_ENV=local
LOG_LEVEL=info
PORT=3000
"@

  Write-IfMissing ".gitignore" @"
.DS_Store
Thumbs.db
*.log

node_modules/
dist/
build/
.cache/
.next/
out/
coverage/

__pycache__/
*.py[cod]
.venv/
venv/
.env/

bin/
obj/
target/
*.class
pkg/
*.exe
*.dll
*.so
*.dylib

.vscode/
.idea/
"@

  Write-IfMissing ".editorconfig" @"
root = true

[*]
charset = utf-8
indent_style = space
indent_size = 2
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
"@

  Write-IfMissing ".prettierrc" "{`n  `"singleQuote`": true,`n  `"semi`": true,`n  `"printWidth`": 100,`n  `"trailingComma`": `"all`"`n}`n"
  Write-IfMissing "tsconfig.base.json" "{`n  `"compilerOptions`": {`n    `"target`": `"ES2022`",`n    `"module`": `"CommonJS`",`n    `"strict`": true,`n    `"esModuleInterop`": true,`n    `"skipLibCheck`": true,`n    `"forceConsistentCasingInFileNames`": true`n  },`n  `"exclude`": [`"node_modules`", `"dist`", `"build`"]`n}`n"
  Write-IfMissing "eslint.config.js" "module.exports = [`n  {`n    ignores: [`n      `"**/dist/**`",`n      `"**/build/**`",`n      `"**/node_modules/**`",`n      `"**/.next/**`",`n      `"**/coverage/**`"`n    ]`n  }`n];`n"
  Write-IfMissing "justfile" "default:`n  @just --list`n`nhelp:`n  @echo `"Common tasks`"`n  @echo `"  just fmt   - run formatting`"`n  @echo `"  just lint  - run linting`"`n  @echo `"  just test  - run tests`"`n  @echo `"  just build - run build`"`n`nfmt:`n  @echo `"Define formatting command for your project.`"`n`nlint:`n  @echo `"Define lint command for your project.`"`n`ntest:`n  @echo `"Define test command for your project.`"`n`nbuild:`n  @echo `"Define build command for your project.`"`n"
  $year = (Get-Date).Year
  Write-IfMissing "LICENSE" "MIT License`n`nCopyright (c) $year`n"

  Write-IfMissing "agents/README.md" @"
# Agents

This folder contains agent contracts, prompts, skills, and policies used by the template.
"@
  Write-IfMissing "agents/skills/README.md" "# Skills`n`nCreate one folder per skill."
  Write-IfMissing "agents/prompts/architect/system.md" "# Architect Agent System Prompt`n"
  Write-IfMissing "agents/policies/guardrails.md" "# Guardrails`n"

  Write-IfMissing ".github/PULL_REQUEST_TEMPLATE.md" @"
## Summary
Describe the change and why it is needed.

## Testing
- Not run (explain why)
- Unit tests added/updated
- Tests passed locally or in CI

## Risks and rollback
Document risks and the rollback approach if the change is sensitive.

## Docs
Note any documentation updates or why none are required.
"@
  Write-IfMissing ".github/dependabot.yml" "version: 2`nupdates:`n  - package-ecosystem: `"npm`"`n    directory: `"/`"`n    schedule:`n      interval: `"weekly`"`n    open-pull-requests-limit: 10`n`n  - package-ecosystem: `"github-actions`"`n    directory: `"/`"`n    schedule:`n      interval: `"weekly`"`n"
  Write-IfMissing ".github/workflows/ci.yml" "name: CI`n`non:`n  push:`n  pull_request:`n`njobs:`n  build:`n    runs-on: ubuntu-latest`n    steps:`n      - uses: actions/checkout@v4`n      - name: CI guidance`n        run: |`n          echo `"CI template: add build and test steps for your stack.`"`n"
  Write-IfMissing ".github/workflows/codeql.yml" "name: CodeQL`n`non:`n  workflow_dispatch:`n  schedule:`n    - cron: `"0 3 * * 1`"`n`njobs:`n  analyze:`n    runs-on: ubuntu-latest`n    permissions:`n      actions: read`n      contents: read`n      security-events: write`n    steps:`n      - uses: actions/checkout@v4`n      - name: CodeQL guidance`n        run: |`n          echo `"Enable CodeQL by adding languages and build steps.`"`n"
  Write-IfMissing ".github/workflows/release.yml" "name: Release`n`non:`n  push:`n    tags:`n      - `"v*.*.*`"`n`njobs:`n  release:`n    runs-on: ubuntu-latest`n    steps:`n      - uses: actions/checkout@v4`n      - name: Release guidance`n        run: |`n          echo `"Add build, package, and publish steps for release artifacts.`"`n"
  Write-IfMissing ".github/workflows/security.yml" "name: Security`n`non:`n  workflow_dispatch:`n  schedule:`n    - cron: `"0 2 * * 4`"`n`njobs:`n  baseline:`n    runs-on: ubuntu-latest`n    steps:`n      - uses: actions/checkout@v4`n      - name: Security guidance`n        run: |`n          echo `"Add security scans (SAST, dependency, and IaC) as needed.`"`n"
  Write-IfMissing "infra/local/docker-compose.yml" "services:`n  postgres:`n    image: postgres:16`n    environment:`n      POSTGRES_PASSWORD: local`n      POSTGRES_USER: local`n      POSTGRES_DB: app`n    ports:`n      - `"5432:5432`"`n    volumes:`n      - postgres_data:/var/lib/postgresql/data`n`n  redis:`n    image: redis:7`n    ports:`n      - `"6379:6379`"`n`nvolumes:`n  postgres_data:`n"

  Write-IfMissing "apps/api/README.md" @"
# API App (Backend)

This is the backend application workspace. Add services under apps/api/src.

## Contracts
- OpenAPI spec lives in apps/api/openapi.yaml.
- Versioning guidance is in docs/api/versioning.md.

## Getting started
- Add a README section for your runtime (Node, Python, .NET, etc.).
- Add run scripts and tests once the service is created.
"@
  Write-IfMissing "apps/web/README.md" @"
# Web App (IBM Carbon)

This is the front-end workspace, intended for IBM Carbon-based UI.

## Structure
- carbon/: theme and design token overrides
- public/: static assets
- src/: application code

## Getting started
- Add your framework and runtime instructions here (React, Next.js, etc.).
- Ensure components follow IBM Carbon guidance.
"@
  Write-IfMissing "apps/web/carbon/theme.scss" "@use `"@carbon/styles/scss/theme`" as *;`n`n$carbon--theme: $g10;`n`n:root {`n  --app-radius: 6px;`n}`n"
  Write-IfMissing "apps/web/carbon/fonts/README.md" @"
# Fonts

Place custom fonts here if required by the UI.

If you rely on IBM Plex via CDN or package manager, document it in apps/web/README.md.
"@
  Write-IfMissing "packages/ui-carbon/README.md" @"
# UI Carbon Package

Shared Carbon components and tokens live here.

## Usage
- Import components from this package in apps/web.
- Keep Carbon upgrades and token changes centralized.
"@
  Write-IfMissing "infra/README.md" @"
# Infrastructure

Infrastructure as code lives here. Use the folder structure that matches your chosen tooling.

## Suggested layout
- bicep/: Azure Bicep templates
- terraform/: Terraform modules and environments
- scripts/: helper scripts for deployment

## Local dependencies
See infra/local/docker-compose.yml for a minimal local stack.
"@
  Write-IfMissing "docs/architecture/architecture.md" @"
# Architecture

## Overview
Describe the target architecture at a high level.

## Context and scope
Summarize key constraints, assumptions, and scope boundaries.

## Components
List major components, their responsibilities, and boundaries.

## Data flows
Reference data flows in data_flows.md and call out trust boundaries.

## Deployment and environments
Describe environments, hosting, and deployment topology.

## Observability
Document logging, metrics, tracing, and health checks.

## Security and compliance
Summarize security controls, identity, and compliance needs.

## Decisions
List ADRs that shape this architecture.
"@
  Write-IfMissing "docs/architecture/risks.md" @"
# Architecture risks

## Current risks
No risks captured yet.

## Tracking
Add new risks with impact, likelihood, mitigation, and owner.
"@
  Write-IfMissing "docs/security/threat_model.md" @"
# Threat model

## Scope
Define in-scope systems, data flows, and trust boundaries.

## Assets
List critical assets and data categories.

## Threats
Capture key threats and attack vectors.

## Assumptions
Record security assumptions and dependencies.
"@
  Write-IfMissing "docs/security/mitigations.md" @"
# Mitigations

## Current mitigations
No mitigations captured yet.

## Tracking
Add mitigation items with owner, status, and validation steps.
"@
}

Write-Host "[scaffold] Applying manifest..."
Apply-Manifest
Write-Host "[scaffold] Hydrating placeholders..."
Hydrate
Write-Host "[scaffold] Done."
