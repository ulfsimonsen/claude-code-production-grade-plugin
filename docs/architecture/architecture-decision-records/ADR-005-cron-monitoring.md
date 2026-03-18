# ADR-005: Cron-Based Pipeline Monitoring

**Status:** Accepted
**Context:** US-4 requires full lifecycle monitoring via CronCreate/CronList/CronDelete (2.1.71). Pre-pipeline, during-pipeline, and post-pipeline cron jobs.

## Architecture

### Cron Job Types

| Phase | Job | Schedule | Script/Command |
|---|---|---|---|
| Pre-pipeline | Dependency freshness check | Configurable (default: daily) | Scan package.json/go.mod/pyproject.toml for outdated deps |
| During-pipeline | Agent health monitor | Every 5 minutes | Check state.json for stuck agents (no progress in >10 minutes) |
| Post-pipeline | Test suite re-run | Configurable (default: daily) | Run test suite, report regressions |
| Post-pipeline | Security scan | Configurable (default: weekly) | Re-run security checks on changed files |
| Post-pipeline | Dependency audit | Configurable (default: weekly) | npm audit / pip-audit / govulncheck |

### Integration Points

1. **sustain.md (post-pipeline)**: After final summary, offer cron setup via Elicitation
2. **improve.md (self-improvement)**: TIME-based termination uses CronCreate for persistence
3. **`.production-grade.yaml`**: Cron schedule configuration

### Monitoring Output

Cron reports written to `Claude-Production-Grade-Suite/.monitoring/`:
```
Claude-Production-Grade-Suite/.monitoring/
├── health/
│   └── {timestamp}-health.json
├── tests/
│   └── {timestamp}-test-results.json
├── security/
│   └── {timestamp}-security-scan.json
└── deps/
    └── {timestamp}-dependency-audit.json
```

### Cron Management

New skill command: `/production-grade cron list` → shows active cron jobs
No new skill needed — the orchestrator handles cron via sustain.md dispatcher.

**Consequences:**
- Cron jobs are opt-in — never auto-created
- CronCreate requires session persistence — jobs may not survive session end (open question from BRD)
- During-pipeline monitoring is session-scoped (dies when pipeline ends)
- Post-pipeline monitoring persists IF Cron supports cross-session scheduling

**Alternatives Considered:**
- Skip cron for v7.0.0: Rejected — user wants full lifecycle monitoring
- External monitoring only: Rejected — CronCreate is native and simpler
