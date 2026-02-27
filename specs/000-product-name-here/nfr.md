# Non-Functional Requirements (NFRs): Knowledge Capture and Reuse Platform

> **Purpose:** Quality attributes and performance targets for all components and features.
> Enforced via testing and monitoring; referenced in feature specs and runbooks.

## Performance

### Capture

- **Latency:** Save to local queue within 100ms (median); 500ms (p95)
  - Test: Local device timing on target hardware (iPhone 12, Pixel 6, Windows Surface)
  - Acceptance: Benchmark baseline in CI

- **Throughput:** Support 10 concurrent captures per device
  - Test: Stress test with 10 simultaneous captures, verify no loss
  - Acceptance: No dropped items or duplicates

- **Upload speed:** 1 MB/s (single file)
  - Test: Network throttling simulation (LTE, WiFi)
  - Acceptance: Achieves target on representative device + network

### Search & Retrieval

- **Search latency:** Keywords return results within 500ms (p95); semantic search within 2s (p95)
  - Test: Load test with 100K items, measure percentiles
  - Acceptance: Automated perf test gate in CI

- **Sync latency:** Device receives outbound changes within 5 seconds (median)
  - Test: Modify item on device A, poll device B until received
  - Acceptance: Automated e2e test in CI

### API Endpoints

| Endpoint | Method | Latency (p95) | Throughput |
|----------|--------|---------------|-----------|
| POST /captures | POST | 200ms | 100 req/sec/user |
| GET /metadata/{id} | GET | 100ms | 1000 req/sec/user |
| GET /search | GET | 500ms (keyword), 2s (semantic) | 100 req/sec/user |
| POST /sync | POST | 300ms | 100 req/sec/user |

---

## Scalability

### Data Volume

- **MVP target:** Support 100K items per user
  - Metadata: ~1KB per item (avg), 100MB per user
  - Blobs: Variable (10MB–500MB per item), 50GB–1TB per user
  - Test: Create / search / sync with target volume
  - Acceptance: Latency does not degrade beyond thresholds

- **Production target:** 1M+ items per user (future)
  - Requires sharding, pagination, lazy loading
  - Acceptance: Architecture supports scaling to 1M without hard rewrite

### Concurrent Users

- **MVP:** 10K concurrent users
  - Test: Load test with ramp-up to 10K simultaneous connections
  - Acceptance: Service remains responsive (< 5s for any API call)

- **Production:** 100K+ concurrent users (future)
  - Requires multi-region deployment, sharding, aggressive caching

### Storage Growth

- **Plan for 10x growth:** If MVP = 1PB, production = 10PB
  - Implement tiered storage (hot → cool → archive)
  - Monitor cost per user; optimize if needed

---

## Reliability & Availability

### Uptime

- **SLA:** 99.9% uptime (43.2 minutes downtime/month)
  - Test: Synthetic monitoring, alerting on SLA violation
  - Acceptance: Monthly incident report with root cause analysis

### Disaster Recovery

- **RTO** (Recovery Time Objective): 1 hour (for critical outages)
  - Test: Failover simulation (backup restoration)
  - Acceptance: Runbook tested annually

- **RPO** (Recovery Point Objective): 5 minutes (data loss tolerance)
  - Test: Verify backup frequency; restore and test
  - Acceptance: Backup tests automated in CI

### Fault Tolerance

- **Graceful degradation:** If search service is down, keyword search fails gracefully; captures continue
  - Test: Chaos engineering; disable service dependencies
  - Acceptance: Monitored on test environment weekly

- **Retry logic:** Failed uploads automatically retry with exponential backoff (max 10 retries)
  - Test: Simulate upstream service failures
  - Acceptance: No data loss over 7 days of failures

---

## Maintainability

### Code Quality

- **Test coverage:** ≥ 80% for critical paths (capture, sync, search)
  - Test: Automated coverage reporting in CI
  - Acceptance: Block merge if coverage drops

- **Complexity:** Cyclomatic complexity ≤ 10 per function
  - Test: SonarQube analysis
  - Acceptance: Refactor if violated

### Documentation

- **API documentation:** 100% of endpoints documented (OpenAPI)
  - Test: Schema completeness check
  - Acceptance: Auto-generated docs served at `/api/docs`

- **Runbooks:** Documented for all critical operational tasks
  - Test: Annual runbook review and walkthrough
  - Acceptance: Runbook present in `docs/runbooks/`

### Observability

- **Logging:** Structured logs (JSON) for all critical operations
  - Test: Log parsing tests in CI
  - Acceptance: Logs queryable in analytics platform

- **Metrics:** Key metrics exposed (latency, throughput, errors, saturation)
  - Test: Metrics collection in staging environment
  - Acceptance: Dashboards published in monitoring tool

- **Tracing:** Distributed tracing for multi-service requests
  - Test: Trace propagation tests
  - Acceptance: Traces available in APM dashboard

---

## Usability

### Response Times

- **Perceived instant:** Actions complete within 100ms (captures, taps)
- **Fast:** Results appear within 500ms (search)
- **Acceptable:** Operations complete within 2s (semantic search, large exports)
- **Unacceptable:** Any action > 5s → user likely to abandon

### Accessibility

- **WCAG 2.1 Level AA** compliance for web UI (Carbon)
- **Platform-native accessibility:** VoiceOver (iOS), TalkBack (Android), Narrator (Windows)
  - Test: Automated scanning + manual testing
  - Acceptance: Checklist before feature ship

---

## Security & Privacy

See [security-baseline.md](security-baseline.md) for detailed requirements.

### Key NFRs

- **Encryption:** TLS 1.2+ in transit, AES-256 at rest
- **Key rotation:** Every 90 days (automated)
- **Audit logging:** Immutable, tamper-proof logs of all data mutations
- **Access control:** RBAC; no user sees another's data

---

## Cost

### Target Metrics

- **Cost per monthly active user (MAU):** < $0.50/month (compute + storage)
  - Test: Monthly cost reporting
  - Acceptance: Optimise if > threshold

- **Storage efficiency:** Deduplication (by content hash) should achieve ≥ 10% reduction
  - Test: Quarterly audit of deduplication savings
  - Acceptance: Track trend over time

---

## Platform Support

### Supported Platforms & Versions

| Platform | Min Version | Target Version | EOL Date |
|----------|------------|-----------------|----------|
| **iOS** | 14 | 17+ | N/A |
| **Android** | 10 | 13+ | N/A |
| **macOS** | 12 | 13+ | N/A |
| **Windows** | 10 | 11 or later | N/A |
| **Web** | Chrome 90+ | Latest LTS | N/A |

---

## NFR Tracking

| NFR | Owner | Measured | Frequency | Status |
|-----|-------|----------|-----------|--------|
| API latency (p95) | `app-dotnet` / `cloud-scrum-master` | CI perf test | Per commit | ✅ |
| Uptime (SLA) | `platform-infra-scrum-master` | Synthetic monitoring | Real-time | ✅ |
| Test coverage (≥80%) | `qa-testing-scrum-master` | SonarQube | Per commit | ✅ |
| WCAG 2.1 Level AA | `ux-carbon-critique` | Axe, manual | Per feature | [TBD] |

---

## See Also

- [high-level-requirements.md](high-level-requirements.md) — Functional requirements (HR-09 covers some NFRs)
- [architecture.md](architecture.md) — Technical approach to meeting NFRs
- [security-baseline.md](security-baseline.md) — Security-specific NFRs and controls
- [docs/runbooks/](../../docs/runbooks/) — Operational runbooks for SLA, failover, scaling
