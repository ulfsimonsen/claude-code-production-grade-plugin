# Production Grade Plugin for Claude Code

**Turn an idea into a production-ready SaaS with a single prompt.** This plugin transforms Claude Code into a complete software development pipeline — from requirements analysis to production deployment. You sit in the CEO/CTO seat, Claude handles the rest.

> **v3.0** — All 13 skills bundled. 7 parallel execution points. Config layer for existing projects. Conflict resolution between skills. Native Teams/TaskList orchestration.

---

## Table of Contents

- [Overview](#overview)
- [What's New in v3.0](#whats-new-in-v30)
- [Installation](#installation)
- [Usage](#usage)
- [Pipeline Phases](#pipeline-phases)
- [13 Bundled Skills](#13-bundled-skills)
- [Configuration](#configuration)
- [Using with Existing Projects](#using-with-existing-projects)
- [Workspace Architecture](#workspace-architecture)
- [Conflict Resolution](#conflict-resolution)
- [Approval Gates](#approval-gates)
- [Partial Execution](#partial-execution)
- [Examples](#examples)
- [FAQ](#faq)
- [License](#license)

---

## Overview

Production Grade Plugin is a **meta-skill orchestrator** for Claude Code. When you say "Build me a SaaS for X", the plugin automatically runs the entire software development pipeline:

```
DEFINE → BUILD → HARDEN → SHIP → SUSTAIN
```

### Highlights

| Feature | Description |
|---------|-------------|
| **Fully Autonomous** | Only 3 approval gates (BRD, Architecture, Production Readiness) |
| **13 Expert Skills** | Each skill is a specialized "expert" agent |
| **7 Parallel Points** | Backend + frontend, containerization, QA + security + review, IaC + remediation, SRE + data science, docs + skills |
| **Config Layer** | `.production-grade.yaml` adapts to existing project structures |
| **Conflict Resolution** | Authority hierarchy prevents overlapping skill outputs |
| **Zero Config** | Works out of the box; config is optional for customization |
| **Real Code** | No stubs, no TODOs — production-ready code that builds and runs |
| **Self-Debugging** | Auto-detects errors, fixes, and retries up to 3 times |

---

## What's New in v3.0

| Area | v2.0 | v3.0 |
|------|------|------|
| Parallelism | 2 points (backend+frontend, security+review) | 7 points across all phases |
| Orchestration | Hand-rolled `pipeline-state.json` | Native Claude Code Teams/TaskList |
| Config | None — hardcoded paths | `.production-grade.yaml` with path/preference overrides |
| Skill loading | Full skill loaded (~1000+ lines) | Router + on-demand phase files (~100-150 lines loaded) |
| Conflicts | Undefined — skills could overlap | Authority hierarchy with dedup rules |
| UX Protocol | Duplicated in all 13 skills (~7,800 tokens) | Single source of truth (~600 tokens) |
| Input validation | None — skills assumed inputs existed | Graceful degradation (Critical/Degraded/Optional) |
| Large skills | Monolithic SKILL.md files | Split into router + phase files (6 skills split) |

### Token Savings

| Area | Before | After | Savings |
|------|--------|-------|---------|
| UX Protocol duplication | ~7,800 tokens | ~600 tokens | 92% |
| Large skill loading | ~25,000 tokens | ~3,000-5,000 tokens | 80% |
| Full pipeline | ~100,000 tokens | ~30,000-40,000 tokens | 65% |

---

## Installation

### Option 1: Marketplace (Recommended)

```bash
/plugin marketplace add nagisanzenin/claude-code-plugins
/plugin install production-grade@nagisanzenin
```

### Option 2: Load directly from directory

```bash
git clone https://github.com/nagisanzenin/claude-code-production-grade-plugin.git
claude --plugin-dir /path/to/claude-code-production-grade-plugin
```

### Requirements

- **Claude Code** (version with plugin support)
- **Docker & Docker Compose** (for local dev environment)
- **Git** (for source control)

---

## Usage

### Trigger Phrases

```
"Build a production-grade SaaS for [idea]"
"Full production pipeline for this project"
"Production ready setup"
"Build me a platform for [description]"
```

### Quick Example

```
You: Build a production-grade SaaS for restaurant management
     with online ordering, table reservations, and staff scheduling.
```

The pipeline will:
1. Research domain & interview you (3-5 multiple choice questions)
2. Write a Business Requirements Document (BRD)
3. **Gate 1: You approve the BRD**
4. Design architecture, API contracts, data models
5. **Gate 2: You approve the Architecture**
6. Implement backend + frontend in parallel
7. Containerize (starts when backend done)
8. QA + Security audit + Code review in parallel
9. IaC + Remediation in parallel
10. SRE readiness + Data scientist (conditional) in parallel
11. **Gate 3: You approve Production Readiness**
12. Documentation + Custom skills in parallel
13. Compound learning capture

### Interaction Model

You **don't need to type anything** — just use arrow keys and Enter to select options. Every question is multiple choice with a "Chat about this" option for free-form input.

---

## Pipeline Phases

### Task Dependency Graph

```
T1: product-manager (BRD)
    ↓ [GATE 1]
T2: solution-architect (Architecture)
    ↓ [GATE 2]
T3a: software-engineer (Backend) ─────┐
T3b: frontend-engineer (Frontend) ────┘ ← PARALLEL #1
    ↓ (T4 starts when T3a done)
T4: devops (Containerization) ─────────── PARALLEL #2
    ↓ (all BUILD done)
T5: qa-engineer (Testing) ────────────┐
T6a: security-engineer (Audit) ───────┤ ← PARALLEL #3
T6b: code-reviewer (Quality) ─────────┘ ← PARALLEL #4
    ↓
T7: devops (IaC + CI/CD) ────────────┐
T8: Remediation (HARDEN fixes) ──────┘ ← PARALLEL #5
    ↓
T9: sre (Production Readiness) ──────┐
T10: data-scientist (conditional) ───┘ ← PARALLEL #6
    ↓ [GATE 3]
T11: technical-writer (Docs) ────────┐
T12: skill-maker (Custom Skills) ────┘ ← PARALLEL #7
    ↓
T13: Compound Learning + Assembly
```

### Phase Summary

| Phase | Tasks | Parallel | User Input |
|-------|-------|----------|------------|
| **DEFINE** | T1 (PM), T2 (Architect) | Sequential | Gate 1, Gate 2 |
| **BUILD** | T3a (Backend), T3b (Frontend), T4 (Containers) | #1, #2 | Autonomous |
| **HARDEN** | T5 (QA), T6a (Security), T6b (Review) | #3, #4 | Autonomous |
| **SHIP** | T7 (IaC), T8 (Remediation), T9 (SRE), T10 (Data Sci) | #5, #6 | Gate 3 |
| **SUSTAIN** | T11 (Docs), T12 (Skills), T13 (Learning) | #7 | Autonomous |

---

## 13 Bundled Skills

| # | Skill | Phase | Role |
|---|-------|-------|------|
| 1 | `production-grade` | Orchestrator | Coordinates entire pipeline via Teams/TaskList |
| 2 | `product-manager` | DEFINE | CEO interview, domain research, BRD with user stories |
| 3 | `solution-architect` | DEFINE | ADRs, tech stack, API contracts, data models, scaffold |
| 4 | `software-engineer` | BUILD | Clean architecture backend: handlers → services → repositories |
| 5 | `frontend-engineer` | BUILD | Design system, components, pages, API clients, a11y |
| 6 | `qa-engineer` | HARDEN | Integration, e2e, performance tests, self-healing protocol |
| 7 | `security-engineer` | HARDEN | STRIDE + OWASP (sole authority), PII, dependency scan |
| 8 | `code-reviewer` | HARDEN | Architecture conformance, quality, performance (no security) |
| 9 | `devops` | BUILD/SHIP | Docker, Terraform, CI/CD, monitoring (no SLOs) |
| 10 | `sre` | SHIP | SLOs (sole authority), chaos engineering, runbooks, capacity |
| 11 | `data-scientist` | SHIP | LLM optimization, A/B testing, data pipelines, cost modeling |
| 12 | `technical-writer` | SUSTAIN | API reference, dev guides, Docusaurus scaffold |
| 13 | `skill-maker` | SUSTAIN | 3-5 project-specific custom skills |

### Split Skills (Router + Phases)

Six large skills are split into a thin router SKILL.md (~100-150 lines) + on-demand phase files for token efficiency:

| Skill | Phases |
|-------|--------|
| `software-engineer` | 5 phases: context analysis, service implementation, cross-cutting, integration, local dev |
| `frontend-engineer` | 5 phases: analysis, design system, components, pages/routes, testing/a11y |
| `security-engineer` | 6 phases: threat modeling, code audit, auth review, data security, supply chain, remediation |
| `sre` | 5 phases: readiness review, SLO definition, chaos engineering, incident management, capacity planning |
| `data-scientist` | 6 phases: system audit, LLM optimization, experiment framework, data pipeline, ML infrastructure, cost modeling |
| `technical-writer` | 4 phases: content audit, API reference, developer guides, Docusaurus scaffold |

---

## Configuration

### `.production-grade.yaml`

Create this file at your project root to customize paths, preferences, and features:

```yaml
version: "3.0"

project:
  name: "my-project"
  language: "typescript"       # typescript | go | python | rust | java
  framework: "nestjs"          # nestjs | express | fastapi | gin | actix | spring
  cloud: "aws"                 # aws | gcp | azure
  architecture: "microservices" # monolith | modular-monolith | microservices

paths:
  api_contracts: "api/openapi/*.yaml"
  architecture_docs: "docs/architecture/"
  adrs: "docs/architecture/architecture-decision-records/"
  services: "services/"
  frontend: "frontend/"
  tests: "tests/"
  terraform: "infrastructure/terraform/"
  ci_cd: ".github/workflows/"
  docs: "docs/"
  runbooks: "docs/runbooks/"
  workspace: "Claude-Production-Grade-Suite/"

preferences:
  test_framework: "jest"       # jest | vitest | pytest | go-test
  orm: "prisma"                # prisma | drizzle | typeorm | sqlalchemy
  ci_provider: "github-actions"
  package_manager: "npm"       # npm | pnpm | yarn | bun
  frontend_framework: "nextjs" # nextjs | nuxt | sveltekit | remix

features:
  frontend: true               # false for API-only projects
  ai_ml: false                 # auto-detected from imports
  multi_tenancy: true
  documentation_site: true
  event_driven: true           # async messaging support
```

If no config file exists, the orchestrator auto-detects settings from your project structure and offers to generate one.

---

## Using with Existing Projects

The plugin adapts to your existing project structure via `.production-grade.yaml`:

1. **Create config** — Copy the template and customize `paths.*` to match your layout
2. **Run specific phases** — Use partial execution: `"Just harden"` to run security + review on existing code
3. **Graceful degradation** — Missing inputs are classified:
   - **Critical**: Skill stops, asks where the input is
   - **Degraded**: Skill continues with partial output, marks gaps
   - **Optional**: Skill skips silently

### Common scenarios:

```
# Audit security on existing codebase
"Run security-engineer on this project"

# Add infrastructure to existing app
"Just ship — add Terraform, CI/CD, and Docker"

# Generate documentation for existing code
"Just document this project"
```

---

## Workspace Architecture

### Project Root (Deliverables)

All production code lives at the project root:

```
project/
├── services/                    # Backend services
├── libs/shared/                 # Shared libraries
├── frontend/                    # Frontend application
├── api/                         # API contracts (OpenAPI, gRPC, AsyncAPI)
├── schemas/                     # Data models (ERD, migrations)
├── tests/                       # Cross-service tests
├── infrastructure/              # Terraform, K8s manifests
├── docs/                        # Documentation + runbooks
├── .github/workflows/           # CI/CD pipelines
├── docker-compose.yml
├── Makefile
├── .production-grade.yaml       # Plugin config (optional)
└── README.md
```

### Agent Workspace (Working Artifacts)

```
Claude-Production-Grade-Suite/
├── .protocols/              # Shared protocols (bootstrap)
├── .orchestrator/           # Pipeline state via TaskList
├── product-manager/         # BRD, research notes
├── solution-architect/      # Architecture analysis
├── software-engineer/       # Implementation plans
├── frontend-engineer/       # UI analysis
├── qa-engineer/             # Test plans, coverage
├── security-engineer/       # Threat models, audit findings
├── code-reviewer/           # Review findings, metrics
├── devops/                  # Infrastructure planning
├── sre/                     # Readiness assessments
├── data-scientist/          # ML analysis
├── technical-writer/        # Writing notes
└── skill-maker/             # Custom skill drafts
```

---

## Conflict Resolution

When skills produce overlapping outputs, the authority hierarchy determines which takes precedence:

| Domain | Sole Authority | Others Must NOT |
|--------|---------------|-----------------|
| OWASP, STRIDE, PII, encryption | **security-engineer** | code-reviewer must not do security review |
| SLO, error budgets, runbooks | **sre** | devops must not define SLOs |
| Code quality, arch conformance | **code-reviewer** | — |
| Infrastructure, CI/CD | **devops** | sre reviews but doesn't provision |
| Requirements (WHAT) | **product-manager** | — |
| Architecture (HOW) | **solution-architect** | — |

### Remediation Feedback Loop

1. HARDEN skills find Critical/High issues
2. Orchestrator creates remediation tasks assigned to BUILD agents
3. BUILD agents fix the code
4. HARDEN re-scans affected files
5. After 2 cycles without resolution → escalate to user

---

## Approval Gates

The plugin pauses only **3 times**:

### Gate 1: BRD Approval
```
> Approve — start architecture (Recommended)
  Show me the BRD details
  I have changes
  Chat about this
```

### Gate 2: Architecture Approval
```
> Approve — start building (Recommended)
  Show architecture details
  I have concerns
  Chat about this
```

### Gate 3: Production Readiness
```
> Ship it — production ready (Recommended)
  Show full report
  Fix issues first
  Chat about this
```

---

## Partial Execution

| Command | Tasks Run |
|---------|----------|
| `"Just define"` | T1, T2 (PM + Architect) |
| `"Just build"` | T3a, T3b, T4 (requires architecture) |
| `"Just harden"` | T5, T6a, T6b (requires implementation) |
| `"Just ship"` | T7-T10 (requires HARDEN output) |
| `"Just document"` | T11 only |
| `"Skip frontend"` | Omit T3b |
| `"Start from architecture"` | Skip T1, start at T2 |

---

## Examples

### E-commerce Platform
```
Build a production-grade SaaS for multi-vendor e-commerce
with seller dashboards, buyer marketplace, and payment processing.
```

### AI Content Platform
```
Full production pipeline for an AI content generation platform
with prompt management, usage metering, and team workspaces.
```
> *Data Scientist (T10) auto-activates for LLM optimization*

### API-Only Backend
```
Build a production-grade REST API for a fintech lending platform.
No frontend needed. Focus on security and compliance.
```
> *Frontend (T3b) automatically skipped*

---

## FAQ

**Q: Does the plugin write working code?**
Yes. Every agent: write → build → test → debug → fix. No stubs or TODOs.

**Q: Can I use it on existing projects?**
Yes. Create `.production-grade.yaml` to map your paths, then run specific phases.

**Q: What languages are supported?**
TypeScript/Node.js, Go, Python, Rust, Java/Kotlin. Specify in config or let the architect choose.

**Q: How does state persist?**
v3.0 uses Claude Code's native TaskList instead of custom JSON files. Pipeline state derives from task statuses.

**Q: Is Docker required?**
Recommended for local dev and build verification. Some phases require it.

**Q: Will it overwrite existing code?**
No. Deliverables go to defined directories. The workspace folder contains only agent artifacts.

---

## Contributing

1. Fork the repo
2. Create a branch: `git checkout -b feature/your-feature`
3. Commit changes
4. Open a Pull Request

### Adding a New Skill

Create `skills/your-skill-name/SKILL.md` with `---` frontmatter. For large skills, use the router + phases pattern.

---

## License

MIT — See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>From idea to production-ready SaaS. One prompt. 13 expert AI agents. 7 parallel execution points.</strong>
</p>
