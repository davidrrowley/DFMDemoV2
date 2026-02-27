# Scaffold v2

1. Unzip into repo root so you have ./scripts
2. Run:
   powershell -ExecutionPolicy Bypass -File .\scripts\scaffold.ps1
3. Verify:
   powershell -ExecutionPolicy Bypass -File .\scripts\verify-scaffold.ps1

## Agent pack install
Run:
- powershell -ExecutionPolicy Bypass -File .\scripts\install-agent-pack.ps1

Edit root docs and config directly. Use install scripts to refresh baseline `origin/` snapshots only.
