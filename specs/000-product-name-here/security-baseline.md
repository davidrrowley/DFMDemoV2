# Security Baseline: Knowledge Capture and Reuse Platform

> **Purpose:** Threat model, security requirements, and mitigations across all platforms and services.
> Referenced by `architecture.md` and enforced via `agents/policies/guardrails.md`.

## Threat Model Summary

| Asset | Threat | Impact | Likelihood | Mitigation |
|-------|--------|--------|------------|-----------|
| **User Data** | Unauthorised access to metadata or blobs | Privacy breach, regulatory violation | Medium | Encryption at rest + RBAC, audit logging, ephemeral credentials |
| **User Credentials** | Credential theft (device token, OAuth token) | Account takeover | Medium | Token rotation, rate limiting, device binding |
| **API Contract** | Man-in-the-middle attack | Data interception | Low | TLS enforcement, certificate pinning (mobile) |
| **Service Availability** | DDoS, ransomware, resource exhaustion | Loss of access | Medium | Rate limiting, WAF, auto-scaling, backup/restore testing |
| **Data Integrity** | Accidental or malicious corruption | Loss of trust, data loss | Low | Write-once blob storage, immutable audit logs, replication |
| **Compliance** | Non-compliance with GDPR, HIPAA, SOC 2 | Fines, legal liability | Low | Privacy controls, data deletion, audit logging, regular assessment |

---

## Security Requirements

### Authentication & Authorisation

- **R-SEC-01:** No user can access another user's data.
  - Implementation: OAuth 2.0 or device tokens scoped to user ID
  - Validation: Unit test + integration test coverage
  - Owner: `app-dotnet` (backend) or `cloud-scrum-master`

- **R-SEC-02:** API calls must be authenticated.
  - Implementation: Bearer token validation on every request
  - Validation: Security test suite in CI
  - Owner: `appsec-tooling`

- **R-SEC-03:** Bulk exports or admin operations require multi-step verification.
  - Implementation: One-time PIN, email confirmation, rate limiting
  - Validation: Threat model walkthrough, test cases
  - Owner: `security-scrum-master`

### Encryption

- **R-SEC-04:** Metadata and blobs are encrypted at rest.
  - Implementation: Platform-managed keys (Azure Storage encryption, CosmosDB TDE) or customer-managed keys
  - Validation: Audit of key rotation logs quarterly
  - Owner: `platform-infra-scrum-master`

- **R-SEC-05:** Data in transit is encrypted (TLS 1.2+).
  - Implementation: TLS enforcement, HSTS headers, certificate pinning (mobile clients optional)
  - Validation: Network capture tests, OWASP ZAP scans
  - Owner: `appsec-tooling`

### Data Privacy

- **R-SEC-06:** Users can export their data in open formats.
  - Implementation: Export API (JSON, CSV) with user-initiated request
  - Validation: E2E test of export completeness and format
  - Owner: `app-typescript` or `app-dotnet`

- **R-SEC-07:** Users can request deletion of their account and data.
  - Implementation: Soft delete on metadata, blob tombstones, audit log retention per policy
  - Validation: 30-day grace period, multi-region cleanup verification
  - Owner: `cloud-scrum-master`

- **R-SEC-08:** Audit logs capture all data mutations.
  - Implementation: Immutable log in separated storage, signed events
  - Validation: Compliance audit checklist, log completeness tests
  - Owner: `platform-infra-scrum-master`

### API Security

- **R-SEC-09:** API enforces rate limiting and request validation.
  - Implementation: 1000 req/min per user, 100 req/sec per IP, payload size limits
  - Validation: Load testing + abuse scenario testing
  - Owner: `cicd-engineer` or `app-dotnet`

- **R-SEC-10:** API errors do not leak sensitive information.
  - Implementation: Generic error messages in production; detailed logs server-side only
  - Validation: Manual review of error responses, automated scan
  - Owner: `appsec-tooling`

### Client Security

- **R-SEC-11:** Mobile clients validate server certificates.
  - Implementation: Automatic certificate pinning (with fallback), no ignore-SSL-errors flags
  - Validation: Network proxy test (intercept HTTPS); must fail until cert is trusted
  - Owner: `android-material` or `windows-fluent` agents

- **R-SEC-12:** Sensitive data in local storage is encrypted.
  - Implementation: SQLite encryption (Android: SQLCipher), Keychain/Credential Manager (iOS/macOS/Windows)
  - Validation: Reverse engineering test; extract APK and verify no cleartext secrets
  - Owner: `android-material` or `windows-fluent` agents

### Threat Detection & Response

- **R-SEC-13:** Security scanning is automated in CI.
  - Implementation: SAST (SonarQube, Semgrep), DAST (OWASP ZAP), dependency scanning (Dependabot)
  - Validation: Baseline scan + regression detection
  - Owner: `cicd-engineer` or `appsec-tooling`

- **R-SEC-14:** Critical vulnerabilities are patched within 24 hours.
  - Implementation: On-call rotation, automated patching for dependency updates, hotfix process
  - Validation: Metric tracking in runbook
  - Owner: `security-scrum-master`

---

## Compliance & Governance

### Standards & Frameworks

- **OWASP Top 10:** Mitigations for A01-A10
- **GDPR / Privacy:** Data minimisation, consent, deletion rights
- **SOC 2:** Annual Type II audit with control verification
- **Industry-specific:** HIPAA (if handling healthcare data), PCI DSS (if storing payment card data)

### Compliance Checklist

- [ ] Privacy impact assessment (PIA) completed
- [ ] Data processing agreement in place with services
- [ ] Regular penetration test (annual minimum)
- [ ] Incident response plan documented and tested
- [ ] Security training completed by all engineers
- [ ] Third-party dependency audit completed
- [ ] Access control policy reviewed quarterly

---

## Implementation Roadmap

### Critical Path (MVP)

1. **Authentication API** — OAuth 2.0 integration (T+0)
2. **Encryption API** — TLS + at-rest encryption (T+2 weeks)
3. **RBAC enforcement** — User isolation in queries (T+4 weeks)
4. **Security scanning in CI** — SAST + dependency checks (T+6 weeks)

### Backlog

- Certificate pinning (mobile)
- Audit logging (immutable)
- Data export/deletion workflows
- Penetration testing
- SOC 2 prep

---

## Owner & Review

- **Responsible:** Security scrum master, App sec tooling agent
- **Review cadence:** Quarterly (or upon breach/incident)
- **Last reviewed:** [date]
- **Next review:** [date + 3 months]

---

## See Also

- [architecture.md](architecture.md) — System components and security boundaries
- [high-level-requirements.md](high-level-requirements.md) — Security requirements (HR-08)
- [agents/policies/guardrails.md](../../agents/policies/guardrails.md) — Enforcement gates in delivery pipeline
- [docs/security/threat_model.md](../../docs/security/threat_model.md) — Detailed threat model and mitigations per feature
