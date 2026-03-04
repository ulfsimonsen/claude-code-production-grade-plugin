# 🏭 Production Grade Plugin for Claude Code

**Biến ý tưởng thành SaaS production-ready chỉ với một câu lệnh.** Plugin này biến Claude Code thành một pipeline phát triển phần mềm hoàn chỉnh — từ phân tích yêu cầu đến deploy production. Bạn ngồi ghế CEO/CTO, Claude lo phần còn lại.

> **v2.0** — Tất cả 13 skill được bundle sẵn. Không cần cài thêm gì.

---

## 📑 Mục Lục

- [Tổng Quan](#-tổng-quan)
- [Cài Đặt](#-cài-đặt)
- [Cách Sử Dụng](#-cách-sử-dụng)
- [Pipeline Phases](#-pipeline-phases)
- [13 Bundled Skills](#-13-bundled-skills)
- [Cấu Trúc Workspace](#-cấu-trúc-workspace)
- [Luồng Hoạt Động Chi Tiết](#-luồng-hoạt-động-chi-tiết)
- [Approval Gates](#-approval-gates)
- [Partial Execution](#-partial-execution)
- [Ví Dụ Sử Dụng](#-ví-dụ-sử-dụng)
- [Cấu Hình & Tùy Chỉnh](#-cấu-hình--tùy-chỉnh)
- [FAQ](#-faq)
- [License](#-license)

---

## 🎯 Tổng Quan

Production Grade Plugin là một **meta-skill orchestrator** cho Claude Code. Khi bạn nói "Build me a SaaS for X", plugin sẽ tự động chạy toàn bộ pipeline phát triển phần mềm:

```
🧠 DEFINE → 🔨 BUILD → 🛡️ HARDEN → 🚀 SHIP → 🔄 SUSTAIN
```

### Điểm Nổi Bật

| Feature | Mô tả |
|---------|-------|
| **Fully Autonomous** | Chỉ cần 3 lần approve (BRD, Architecture, Production Readiness) |
| **13 Expert Skills** | Mỗi skill là một "chuyên gia" chuyên biệt |
| **Zero Config** | Cài một lần, tất cả skill sẵn sàng |
| **Real Code** | Không stub, không TODO — code chạy được thật |
| **Self-Debugging** | Tự phát hiện lỗi, sửa, retry tối đa 3 lần |
| **Production Standards** | Clean architecture, OWASP, STRIDE, CI/CD, monitoring |

---

## 📦 Cài Đặt

### Cách 1: Marketplace (Khuyến nghị)

```bash
/plugin marketplace add nagisanzenin/claude-code-plugins
/plugin install production-grade@nagisanzenin
```

### Cách 2: Load trực tiếp từ thư mục

```bash
git clone https://github.com/nagisanzenin/claude-code-production-grade-plugin.git
claude --plugin-dir /path/to/claude-code-production-grade-plugin
```

### Yêu Cầu

- **Claude Code** (phiên bản hỗ trợ plugin)
- **Docker & Docker Compose** (để chạy local dev environment)
- **Git** (để quản lý source code)

> 💡 Không cần cài thêm tool nào khác. Pipeline sẽ tự setup mọi thứ cần thiết trong Docker.

---

## 🚀 Cách Sử Dụng

### Trigger Phrases

Nói một trong các câu sau để kích hoạt pipeline:

```
"Build a production-grade SaaS for [ý tưởng]"
"Full production pipeline for this project"
"Production ready setup"
"Run the complete pipeline"
"Build me a platform for [mô tả]"
```

### Ví dụ Nhanh

```
You: Build a production-grade SaaS for restaurant management
     with online ordering, table reservations, and staff scheduling.
```

Pipeline sẽ tự động:
1. 📋 Phỏng vấn bạn (3-5 câu hỏi multiple choice)
2. 🔍 Research domain & competitors
3. 📄 Viết Business Requirements Document (BRD)
4. ⏸️ **Gate 1: Bạn approve BRD**
5. 🏗️ Thiết kế architecture, API contracts, data models
6. ⏸️ **Gate 2: Bạn approve Architecture**
7. 💻 Implement backend + frontend code
8. 🧪 Viết & chạy tests (unit, integration, e2e)
9. 🔒 Security audit (STRIDE + OWASP)
10. 📝 Code review tự động
11. ☁️ Setup Terraform, CI/CD, Docker, K8s
12. 🏥 SRE production readiness check
13. ⏸️ **Gate 3: Bạn approve Production Readiness**
14. 📚 Generate documentation
15. 🧩 Tạo custom skills cho project

### Interaction Model

Bạn **không cần gõ gì** — chỉ dùng arrow keys ↑↓ và Enter để chọn options. Mọi câu hỏi đều là multiple choice với option "Chat about this" ở cuối nếu bạn muốn gõ tự do.

---

## 🔄 Pipeline Phases

```
DEFINE          BUILD              HARDEN             SHIP            SUSTAIN
  │               │                  │                  │               │
  ▼               ▼                  ▼                  ▼               ▼
Product       Software           QA Engineer        DevOps            SRE
Manager       Engineer           Security Eng       (CI/CD,IaC)      (Reliability)
(BRD/PRD)     (Services)         Code Reviewer
              Frontend Eng
Solution      (UI/UX)
Architect     Data Scientist
(Design)      (AI/ML)            Technical Writer
                                 (Docs)
```

### Phase Details

| Phase | Tên | Mô tả | User Input? |
|-------|-----|-------|-------------|
| 1 | **DEFINE - Product Manager** | Phỏng vấn CEO, research domain, viết BRD/PRD | ✅ Gate 1: Approve BRD |
| 2 | **DEFINE - Solution Architect** | System design, tech stack, API contracts, data models, scaffold | ✅ Gate 2: Approve Architecture |
| 3a | **BUILD - Software Engineer** | Backend implementation: services, handlers, repositories, middleware | ❌ Autonomous |
| 3b | **BUILD - Frontend Engineer** | UI: design system, components, pages, API clients (nếu cần) | ❌ Autonomous |
| 4 | **BUILD - QA Engineer** | Unit, integration, e2e, performance tests + self-healing | ❌ Autonomous |
| 5a | **HARDEN - Security Engineer** | STRIDE threat modeling, OWASP audit, compliance check | ❌ Autonomous |
| 5b | **HARDEN - Code Reviewer** | Architecture conformance, code quality, auto-fix | ❌ Autonomous |
| 6 | **SHIP - DevOps** | Terraform, CI/CD, Docker/K8s, monitoring, security scanning | ❌ Autonomous |
| 7 | **SHIP - SRE** | Production readiness, chaos engineering, incident management | ✅ Gate 3: Approve Readiness |
| 7b | **SHIP - Data Scientist** | AI/ML/LLM optimization (tự kích hoạt nếu phát hiện AI usage) | ❌ Conditional |
| 8 | **SUSTAIN - Technical Writer** | API reference, dev guides, Docusaurus site | ❌ Autonomous |
| 9 | **SUSTAIN - Skill Maker** | Tạo custom skills riêng cho project | ❌ Autonomous |

> 🔀 **Parallelization:** Phases 3a+3b chạy song song. Phases 5a+5b chạy song song.

---

## 🧩 13 Bundled Skills

### 1. `production-grade` — Master Orchestrator
- Điều phối toàn bộ pipeline end-to-end
- Quản lý state, context bridging giữa các skill
- Adaptive: tự điều chỉnh plan dựa trên kết quả từng phase
- 3 approval gates với UX multiple-choice

### 2. `product-manager` — Business Requirements
- Phỏng vấn CEO/CTO (3-5 câu hỏi focused)
- Research domain qua web search
- Viết BRD với user stories, acceptance criteria, business rules
- Tự verify implementation matches BRD sau khi code xong

### 3. `solution-architect` — System Design
- Architecture Decision Records (ADRs)
- C4 diagrams (context, container, sequence)
- Tech stack selection với rationale
- OpenAPI 3.1, gRPC proto, AsyncAPI specs
- ERD, SQL migrations, data flow diagrams
- Project scaffold với health checks, logging, graceful shutdown

### 4. `software-engineer` — Backend Implementation
- Clean architecture: handlers → services → repositories
- Dependency injection, DTO mapping, domain models
- Multi-tenancy, RBAC, audit trail
- Payment integration (Stripe/Paddle abstraction)
- Feature flags, caching, rate limiting
- Local dev environment (Docker Compose + seed data)

### 5. `frontend-engineer` — UI/UX
- Design system với tokens, components, patterns
- Next.js / Vue / Svelte support
- API client generation từ OpenAPI specs
- Accessibility (WCAG 2.1 AA)
- Storybook documentation

### 6. `data-scientist` — AI/ML/LLM Optimization
- Prompt engineering & token optimization
- LLM caching strategies
- A/B testing framework
- Cost modeling & analytics pipeline
- Tự kích hoạt khi phát hiện AI/ML usage trong code

### 7. `qa-engineer` — Testing
- Unit, integration, contract, e2e, performance tests
- Self-healing test protocol: phân biệt test bug vs implementation bug
- Coverage reports
- Auto-retry & debug failed tests

### 8. `security-engineer` — Security Audit
- STRIDE threat modeling
- OWASP Top 10 code audit
- PII inventory & encryption review
- Dependency vulnerability analysis
- Penetration test plans
- Compliance (GDPR, SOC2, HIPAA)

### 9. `code-reviewer` — Quality Gate
- Architecture conformance check
- Code quality metrics
- Performance review
- Auto-fix cho critical & high severity issues
- Findings report theo severity

### 10. `devops` — Infrastructure & Deployment
- Terraform IaC (AWS / GCP / Azure)
- CI/CD pipelines (GitHub Actions)
- Docker multi-stage builds
- Kubernetes manifests
- Monitoring: Prometheus, Grafana dashboards
- Security scanning trong pipeline

### 11. `sre` — Site Reliability Engineering
- Production readiness checklist
- SLO/SLI definitions
- Chaos engineering scenarios
- Capacity planning
- Incident management & runbooks
- On-call rotation setup

### 12. `technical-writer` — Documentation
- API reference (auto-generated)
- Developer guides
- Operational docs & runbooks
- Docusaurus site scaffold
- Architecture decision documentation

### 13. `skill-maker` — Meta Skill Creator
- Phân tích project patterns
- Tạo 3-5 custom skills riêng cho project
- Package & publish lên marketplace
- Tự tạo SKILL.md, plugin.json

---

## 📁 Cấu Trúc Workspace

Tất cả output được tổ chức trong một folder duy nhất:

```
Claude-Production-Grade-Suite/
├── .orchestrator/                # Pipeline state & logs
│   ├── pipeline-state.json       # Phase hiện tại, status, timestamps
│   ├── decisions-log.md          # Tất cả approvals & decisions
│   ├── execution-plan.md         # Plan cho pipeline run
│   └── agent-activity.log        # Cross-agent activity feed
│
├── product-manager/              # Phase 1: Requirements
│   ├── BRD/                      # Business Requirements Documents
│   │   ├── INDEX.md              # Table of contents
│   │   └── YYYY-MM-DD-*.md      # Feature documents
│   └── research/                 # Domain research notes
│
├── solution-architect/           # Phase 2: Architecture
│   ├── docs/                     # ADRs, diagrams, tech stack
│   ├── api/                      # OpenAPI, gRPC, AsyncAPI specs
│   ├── schemas/                  # ERD, SQL migrations
│   └── scaffold/                 # Project structure template
│
├── software-engineer/            # Phase 3a: Backend
│   ├── services/                 # Service implementations
│   │   └── <service-name>/
│   │       ├── src/              # handlers, services, repositories, models
│   │       ├── tests/            # unit, integration, fixtures
│   │       └── Makefile
│   ├── libs/shared/              # Shared libraries
│   ├── scripts/                  # dev-setup, seed-data, migrate
│   ├── docker-compose.dev.yml
│   └── Makefile
│
├── frontend-engineer/            # Phase 3b: Frontend (nếu có)
│   ├── app/                      # Frontend application
│   ├── storybook/                # Component docs
│   └── logs/
│
├── qa-engineer/                  # Phase 4: Testing
│   ├── unit/                     # Unit tests
│   ├── integration/              # Integration tests
│   ├── e2e/                      # End-to-end tests
│   ├── performance/              # Load tests
│   └── coverage/                 # Coverage reports
│
├── security-engineer/            # Phase 5a: Security
│   ├── threat-model/             # STRIDE analysis
│   ├── code-audit/               # OWASP review
│   ├── pen-test/                 # Penetration test plans
│   └── remediation/              # Fix plans
│
├── code-reviewer/                # Phase 5b: Quality
│   ├── findings/                 # Review findings by severity
│   ├── metrics/                  # Code quality metrics
│   └── auto-fixes/               # Applied fixes
│
├── devops/                       # Phase 6: Infrastructure
│   ├── terraform/                # Multi-cloud IaC
│   ├── ci-cd/                    # Pipeline configs
│   ├── containers/               # Docker, K8s manifests
│   └── monitoring/               # Prometheus, Grafana
│
├── sre/                          # Phase 7: Operations
│   ├── production-readiness/     # Checklist & findings
│   ├── chaos/                    # Chaos engineering
│   ├── incidents/                # Incident management
│   └── runbooks/                 # Operational runbooks
│
├── data-scientist/               # Phase 7b: AI/ML (conditional)
│   ├── analysis/                 # System audit, cost models
│   ├── llm-optimization/         # Prompt library, caching
│   ├── experiments/              # A/B testing
│   └── data-pipeline/            # Analytics, ETL
│
├── technical-writer/             # Phase 8: Documentation
│   ├── docs/                     # All documentation
│   ├── docusaurus/               # Doc site scaffold
│   └── api-reference/            # Auto-generated API docs
│
└── skill-maker/                  # Phase 9: Custom Skills
    └── custom-skills/            # Project-specific skills
```

---

## 🔄 Luồng Hoạt Động Chi Tiết

### 1. Initialization
```
User: "Build me a SaaS for X"
  ↓
Orchestrator tạo workspace + research domain
  ↓
Hiển thị Execution Plan (phases nào active, parallelization)
  ↓
Tự động bắt đầu Phase 1 (KHÔNG hỏi "should I proceed?")
```

### 2. Context Bridging

Mỗi phase đọc output của phase trước — không hỏi lại câu hỏi đã trả lời:

| Phase | Đọc từ | Ghi vào |
|-------|--------|---------|
| Product Manager | User interview | `product-manager/` |
| Solution Architect | `product-manager/BRD/` | `solution-architect/` |
| Software Engineer | `solution-architect/api/`, `schemas/`, `scaffold/` | `software-engineer/` |
| Frontend Engineer | `solution-architect/api/`, `product-manager/BRD/` | `frontend-engineer/` |
| QA Engineer | `software-engineer/`, `frontend-engineer/`, `solution-architect/` | `qa-engineer/` |
| Security Engineer | All implementation folders | `security-engineer/` |
| Code Reviewer | All implementation + test folders | `code-reviewer/` |
| DevOps | `solution-architect/`, `software-engineer/` | `devops/` |
| SRE | `devops/`, `solution-architect/` | `sre/` |
| Data Scientist | `software-engineer/`, `solution-architect/`, `product-manager/` | `data-scientist/` |
| Technical Writer | **ALL** folders | `technical-writer/` |
| Skill Maker | **ALL** folders | `skill-maker/` |

### 3. Adaptive Orchestration

Orchestrator không phải runner tuần tự — nó **intelligent** và tự điều chỉnh:

| Tình huống | Hành động |
|-----------|----------|
| User nói "no frontend" | Skip Phase 3b, đơn giản hóa DevOps |
| Architect chọn monolith | Bỏ K8s, đơn giản CI/CD |
| Code dùng LLM APIs | Tự bật Phase 7b (Data Scientist) |
| Security tìm thấy critical vuln | Pause → gọi Software Engineer sửa → resume |
| Test fail > 20% | Flag cho user review |
| User nói "skip testing" | Cảnh báo, tiếp tục nếu user insist |

### 4. Self-Debugging Protocol

Mọi agent đều follow protocol này:
1. Viết code → **chạy thử** (`make build`, `docker build`)
2. Nếu lỗi → đọc error → phân tích root cause → sửa → retry
3. Sau 3 lần fail → dừng lại, report chi tiết cho user
4. **Không bao giờ** để broken code rồi đi tiếp

---

## 🚦 Approval Gates

Plugin chỉ dừng lại **3 lần** để hỏi bạn:

### Gate 1: BRD Approval (sau Phase 1)
```
┌─────────────────────────────────────────────┐
│ Gate 1: BRD                                 │
│                                             │
│ BRD complete: 12 user stories,              │
│ 8 acceptance criteria. Approve?             │
│                                             │
│ > Approve — start architecture (Recommended)│
│   Show me the BRD details                   │
│   I have changes                            │
│   Chat about this                           │
└─────────────────────────────────────────────┘
```

### Gate 2: Architecture Approval (sau Phase 2)
```
┌─────────────────────────────────────────────┐
│ Gate 2: Architecture                        │
│                                             │
│ Architecture complete: [tech stack].        │
│ Approve to start building?                  │
│                                             │
│ > Approve — start building (Recommended)    │
│   Show architecture details                 │
│   I have concerns                           │
│   Chat about this                           │
└─────────────────────────────────────────────┘
```

### Gate 3: Production Readiness (sau Phase 7)
```
┌─────────────────────────────────────────────┐
│ Gate 3: Ship                                │
│                                             │
│ All phases complete. Ship it?               │
│                                             │
│ > Ship it — production ready (Recommended)  │
│   Show full report                          │
│   Fix issues first                          │
│   Chat about this                           │
└─────────────────────────────────────────────┘
```

> 💡 Mọi tương tác khác giữa các gate đều **autonomous** — pipeline tự quyết định và report.

---

## ⚡ Partial Execution

Không cần chạy full pipeline. Bạn có thể chạy từng phần:

| Lệnh | Phases chạy |
|-------|------------|
| `"Just define"` | Product Manager → Solution Architect |
| `"Just build"` | Software Engineer → QA (yêu cầu có architecture) |
| `"Just harden"` | Security Engineer → Code Reviewer (yêu cầu có code) |
| `"Just ship"` | DevOps → SRE (yêu cầu có code) |
| `"Just document"` | Technical Writer (yêu cầu có output từ phase trước) |
| `"Skip frontend"` | Bỏ Phase 3b |
| `"Start from architecture"` | Bỏ Product Manager, bắt đầu Phase 2 |

---

## 💡 Ví Dụ Sử Dụng

### E-commerce Platform
```
Build a production-grade SaaS for multi-vendor e-commerce
with seller dashboards, buyer marketplace, and payment processing.
```

### Project Management Tool
```
Build me a production-ready project management platform
like Linear, with sprint planning, issue tracking, and team collaboration.
```

### AI Content Platform
```
Full production pipeline for an AI content generation platform
with prompt management, usage metering, and team workspaces.
```
→ *Phase 7b (Data Scientist) sẽ tự kích hoạt cho AI/LLM optimization*

### API-Only Backend
```
Build a production-grade REST API for a fintech lending platform.
No frontend needed. Focus on security and compliance.
```
→ *Phase 3b (Frontend) tự bị skip*

---

## ⚙️ Cấu Hình & Tùy Chỉnh

### Plugin Metadata

```json
{
  "name": "production-grade",
  "version": "2.0.0",
  "author": "nagisanzenin",
  "license": "MIT"
}
```

### Tùy Chỉnh Tech Stack

Bạn có thể specify tech stack khi trigger:

```
Build a production-grade SaaS for X using:
- TypeScript + NestJS backend
- Next.js frontend
- PostgreSQL + Redis
- Deploy on AWS
```

Solution Architect sẽ respect preferences của bạn trong ADRs.

### Cloud Support

| Cloud | Terraform | CI/CD | Containers | Monitoring |
|-------|-----------|-------|------------|------------|
| **AWS** | ✅ ECS/EKS, RDS, SQS/SNS | ✅ GitHub Actions | ✅ Docker, K8s | ✅ CloudWatch |
| **GCP** | ✅ GKE/Cloud Run, Cloud SQL | ✅ GitHub Actions | ✅ Docker, K8s | ✅ Cloud Monitoring |
| **Azure** | ✅ AKS, Azure SQL, Service Bus | ✅ GitHub Actions | ✅ Docker, K8s | ✅ Azure Monitor |
| **Multi-cloud** | ✅ Provider-agnostic modules | ✅ | ✅ | ✅ |

---

## ❓ FAQ

### Q: Plugin có thực sự viết code chạy được không?
**A:** Có. Mọi agent đều follow protocol "viết code → chạy → debug → sửa". Không có stub hay TODO trong production code. Build phải pass, tests phải green.

### Q: Mất bao lâu để chạy full pipeline?
**A:** Tùy project complexity. Một SaaS đơn giản (5-10 endpoints) khoảng 30-60 phút. Complex platform có thể 2-4 giờ.

### Q: Tôi có thể dừng giữa chừng và tiếp tục sau không?
**A:** Pipeline state được lưu trong `.orchestrator/pipeline-state.json`. Tuy nhiên, resume mid-pipeline phụ thuộc vào session context của Claude Code.

### Q: Plugin support ngôn ngữ nào?
**A:** TypeScript/Node.js, Go, Python, Rust, Java/Kotlin. Solution Architect sẽ chọn based on requirements, hoặc bạn specify.

### Q: Có cần Docker không?
**A:** Khuyến nghị có Docker để chạy local dev environment và verify builds. Một số phase (DevOps, QA integration tests) cần Docker.

### Q: Plugin có ghi đè code hiện tại không?
**A:** Không. Tất cả output nằm trong `Claude-Production-Grade-Suite/`. Chỉ copy vào project root khi bạn approve ở bước Final Assembly.

### Q: Tôi muốn thêm skill mới riêng cho project thì sao?
**A:** Phase 9 (Skill Maker) tự động phân tích project và tạo 3-5 custom skills. Hoặc bạn trigger `skill-maker` riêng: `"Make a skill for [mô tả]"`.

---

## 🏗️ Architecture Highlights

### Clean Architecture (Software Engineer)
```
Handler (thin) → Service (business logic) → Repository (data access)
     ↓                    ↓                        ↓
  Validate          Apply rules              Query DB
  Delegate          Emit events              Cache aside
  Respond           Return Result            Tenant scoped
```

### Security Layers (Security Engineer)
- **STRIDE** threat modeling cho mỗi component
- **OWASP Top 10** code-level audit
- Auto-fix critical/high vulnerabilities
- PII inventory + encryption strategy
- Dependency vulnerability analysis

### Production Standards (SRE + DevOps)
- Health checks (`/healthz`, `/readyz`)
- Structured JSON logging với trace IDs
- Graceful shutdown handling
- Circuit breaker + retry patterns
- Rate limiting (global + per-tenant)
- Feature flags abstraction
- Multi-tenancy at data layer

---

## 🤝 Contributing

1. Fork repo
2. Tạo branch: `git checkout -b feature/your-feature`
3. Commit: `git commit -m "Add your feature"`
4. Push: `git push origin feature/your-feature`
5. Mở Pull Request

### Thêm Skill Mới

Tạo folder trong `skills/your-skill-name/` với file `SKILL.md` theo format:

```markdown
---
name: your-skill-name
description: When to trigger this skill...
---

# Your Skill Name

## Overview
...

## When to Use
...

## Process Flow
...
```

---

## 📜 License

MIT — Xem file [LICENSE](LICENSE) để biết chi tiết.

---

## 🙏 Credits

Tạo bởi [nagisanzenin](https://github.com/nagisanzenin).

---

<p align="center">
  <strong>Từ ý tưởng → Production-ready SaaS. Một câu lệnh. 13 chuyên gia AI.</strong>
</p>
