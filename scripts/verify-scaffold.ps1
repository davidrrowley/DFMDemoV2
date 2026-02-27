$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$Manifest = Join-Path $RootDir "scripts\scaffold.manifest.txt"
$missing = $false

Get-Content $Manifest | ForEach-Object {
  $line = $_.Trim()
  if ($line.Length -eq 0 -or $line.StartsWith("#")) { return }
  $parts = $line.Split(" ",2)
  $type = $parts[0]
  $path = $parts[1]
  $full = Join-Path $RootDir $path

  if ($type -eq "D" -and !(Test-Path $full -PathType Container)) {
    Write-Host "Missing directory: $path"
    $missing = $true
  }
  if ($type -eq "F" -and !(Test-Path $full -PathType Leaf)) {
    Write-Host "Missing file: $path"
    $missing = $true
  }
}

if ($missing) { throw "Verification failed." }
Write-Host "Verification passed."
