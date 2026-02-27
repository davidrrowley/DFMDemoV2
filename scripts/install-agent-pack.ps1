# Install agent pack into an existing scaffold repo.
# Compatible with Windows PowerShell 5.1 and PowerShell 7+
#
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File .\scripts\install-agent-pack.ps1
#
# Options:
#   -Source .\origin
#   -Destination <repo root>
#   -Force   (overwrite existing files)

param(
  [string]$Source = (Join-Path $PSScriptRoot "..\origin"),
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
      # PS 5.1-safe relative path calculation
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

Write-Host ("[install] Source: {0}" -f $Source)
Write-Host ("[install] Destination: {0}" -f $Destination)
Write-Host ("[install] Force overwrite: {0}" -f [bool]$Force)

Copy-Tree -From $Source -To $Destination -Force:$Force

Write-Host "[install] Done."
