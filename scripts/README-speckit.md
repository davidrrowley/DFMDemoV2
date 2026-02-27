# Spec-kit add-on

This add-on installs `.specify/` assets into the template repo and updates `scripts/scaffold.manifest.txt`
so `scaffold.ps1` and `verify-scaffold.ps1` recognise the spec-kit structure.

Run:
- powershell -ExecutionPolicy Bypass -File .\scripts\install-speckit.ps1

Use `-Force` to overwrite existing `.specify` files.

Edit root docs and config directly. Use install scripts to refresh baseline `origin/` snapshots only.
