# Install Spec-kit (.specify) assets into the repository template.
# Compatible with Windows PowerShell 5.1 and PowerShell 7+
#
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File .\scripts\install-speckit.ps1
# Overwrite existing:
#   powershell -ExecutionPolicy Bypass -File .\scripts\install-speckit.ps1 -Force

param(
  [string]$Source = (Join-Path $PSScriptRoot "..\origin\.specify"),
  [string]$Destination = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Copy-Tree {
  param(
    [Parameter(Mandatory=$true)][string]$From,
    [Parameter(Mandatory=$true)][string]$To,
    [switch]$Force
  )

  if (!(Test-Path $From)) { throw "Source not found: $From" }
  if (!(Test-Path $To)) { New-Item -ItemType Directory -Path $To | Out-Null }

  $FromResolved = (Resolve-Path $From).Path.TrimEnd('\')
  $ToResolved   = (Resolve-Path $To).Path.TrimEnd('\')

  Push-Location $FromResolved
  try {
    Get-ChildItem -Recurse -Force | ForEach-Object {
      $rel = (Resolve-Path -LiteralPath $_.FullName -Relative) -replace '^[.][\\/]', ''
      $destPath = Join-Path $ToResolved $rel

      if ($_.PSIsContainer) {
        if (!(Test-Path $destPath)) {
          New-Item -ItemType Directory -Path $destPath | Out-Null
        }
      }
      else {
        $parent = Split-Path $destPath -Parent
        if (!(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }

        if ((Test-Path $destPath) -and (-not $Force)) {
          Write-Host ("SKIP  {0} (exists)" -f $rel)
        }
        else {
          Copy-Item -LiteralPath $_.FullName -Destination $destPath -Force
          Write-Host ("COPY  {0}" -f $rel)
        }
      }
    }
  }
  finally {
    Pop-Location
  }
}

function Ensure-ManifestEntries {
  param(
    [string]$ManifestPath,
    [string[]]$Entries
  )

  if (!(Test-Path $ManifestPath)) {
    Write-Host "[speckit] Manifest not found, skipping: $ManifestPath"
    return
  }

  $current = Get-Content $ManifestPath -Raw
  $toAdd = @()
  foreach ($e in $Entries) {
    if ($current -notmatch [regex]::Escape($e)) {
      $toAdd += $e
    }
  }

  if ($toAdd.Count -gt 0) {
    Add-Content -Path $ManifestPath -Value "`n# Spec-kit (.specify) assets`n" -Encoding UTF8
    $toAdd | ForEach-Object { Add-Content -Path $ManifestPath -Value $_ -Encoding UTF8 }
    Write-Host ("[speckit] Added {0} manifest entries." -f $toAdd.Count)
  }
  else {
    Write-Host "[speckit] Manifest already contains spec-kit entries."
  }
}

Write-Host ("[speckit] Source: {0}" -f $Source)
Write-Host ("[speckit] Destination: {0}" -f $Destination)
Write-Host ("[speckit] Force overwrite: {0}" -f [bool]$Force)

# Copy origin/.specify -> repo root/.specify
Copy-Tree -From $Source -To (Join-Path $Destination ".specify") -Force:$Force

# Update scaffold manifest so scaffold/verify know about these paths
$manifest = Join-Path $Destination "scripts\scaffold.manifest.txt"

$entries = @(
  "D .specify",
  "D .specify/memory",
  "D .specify/scripts",
  "D .specify/scripts/powershell",
  "D .specify/templates",
  "F .specify/README.md",
  "F .specify/memory/constitution.md",
  "F .specify/scripts/powershell/check-prerequisites.ps1",
  "F .specify/scripts/powershell/common.ps1",
  "F .specify/scripts/powershell/create-new-feature.ps1",
  "F .specify/scripts/powershell/setup-plan.ps1",
  "F .specify/scripts/powershell/update-agent-context.ps1",
  "F .specify/templates/agent-file-template.md",
  "F .specify/templates/checklist-template.md",
  "F .specify/templates/constitution-template.md",
  "F .specify/templates/plan-template.md",
  "F .specify/templates/spec-template.md",
  "F .specify/templates/tasks-template.md"
)

Ensure-ManifestEntries -ManifestPath $manifest -Entries $entries

Write-Host "[speckit] Done."
