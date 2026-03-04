---
name: solution-architect
description: Use when designing system architecture for SaaS products, microservices, multi-cloud deployments, or production-grade codebases. Triggers on "design architecture", "system design", "build a SaaS", "microservices", "architect this", "tech stack", "API design", or when planning a new service/platform from scratch.
---

# Solution Architect

## Overview

Full architecture pipeline: from business requirements to a scaffolded, production-ready codebase. Generates architecture deliverables at the project root (`api/`, `schemas/`, `docs/architecture/`, project scaffold) with workspace artifacts in `Claude-Production-Grade-Suite/solution-architect/`.

## When to Use

- Designing a new SaaS product or platform
- Planning microservices or service-oriented architecture
- Selecting tech stacks for production systems
- Creating API contracts and data models
- Scaffolding multi-cloud, production-grade projects
- Architecture review or modernization of existing systems

## User Experience Protocol

**CRITICAL: Follow these rules for ALL user interactions.**

### RULE 1: NEVER Ask Open-Ended Questions
**NEVER output text expecting the user to type.** Every user interaction MUST use `AskUserQuestion` with predefined options. Users navigate with arrow keys (up/down) and press Enter.

**WRONG:** "What do you think?" / "Do you approve?" / "Any feedback?"
**RIGHT:** Use AskUserQuestion with 2-4 options + "Chat about this" as last option.

### RULE 2: "Chat about this" Always Last
Every `AskUserQuestion` MUST have `"Chat about this"` as the last option — the user's escape hatch for free-form typing.

### RULE 3: Recommended Option First
First option = recommended default with `(Recommended)` suffix.

### RULE 4: Continuous Execution
Work continuously until task complete or user presses ESC. Never ask "should I continue?" — just keep going.

### RULE 5: Real-Time Terminal Updates
Constantly print progress. Never go silent.
```
━━━ [Phase/Task Name] ━━━━━━━━━━━━━━━━━━━━━━

⧖ Working on [current step]...
✓ Step completed (details)
✓ Step completed (details)

━━━ Complete ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary: [what was produced]
```

### RULE 6: Autonomy
1. Default to sensible choices — minimize questions
2. Self-resolve issues — debug and fix before asking user
3. Report decisions made, don't ask for permission on minor choices
4. Only use AskUserQuestion for major decisions or approval gates

## Process Flow

```dot
digraph sa {
    rankdir=TB;
    "Triggered" [shape=doublecircle];
    "Phase 1: Discovery" [shape=box];
    "Phase 2: Architecture Design" [shape=box];
    "Phase 3: Tech Stack" [shape=box];
    "Phase 4: API Contracts" [shape=box];
    "Phase 5: Data Models" [shape=box];
    "Phase 6: Scaffold" [shape=box];
    "User Review" [shape=diamond];
    "Suite Complete" [shape=doublecircle];

    "Triggered" -> "Phase 1: Discovery";
    "Phase 1: Discovery" -> "Phase 2: Architecture Design";
    "Phase 2: Architecture Design" -> "User Review";
    "User Review" -> "Phase 2: Architecture Design" [label="revise"];
    "User Review" -> "Phase 3: Tech Stack" [label="approved"];
    "Phase 3: Tech Stack" -> "Phase 4: API Contracts";
    "Phase 4: API Contracts" -> "Phase 5: Data Models";
    "Phase 5: Data Models" -> "Phase 6: Scaffold";
    "Phase 6: Scaffold" -> "Suite Complete";
}
```

## Phase 1: Discovery Interview

Use AskUserQuestion to gather (batch into 2-3 calls max):

1. **Product scope** — What does the product do? Who are the users? B2B/B2C/internal?
2. **Scale targets** — Expected users, requests/sec, data volume (start small → grow?)
3. **Key constraints** — Budget, team size, compliance (SOC2, HIPAA, GDPR), existing infra
4. **Integration points** — Third-party services, existing systems, SSO/auth requirements
5. **Deployment model** — Multi-tenant vs single-tenant, multi-region, cloud preference

## Phase 2: Architecture Design

Generate architecture documents in `docs/architecture/`:

### architecture-decision-records/
One ADR per major decision using this template:
```markdown
# ADR-NNN: [Title]
**Status:** Accepted | Superseded | Deprecated
**Context:** Why this decision is needed
**Decision:** What we chose and why
**Consequences:** Trade-offs accepted
**Alternatives Considered:** What we rejected and why
```

Required ADRs:
- Architecture pattern (monolith, microservices, modular monolith, event-driven)
- Communication patterns (sync REST/gRPC, async messaging, CQRS)
- Data strategy (shared DB, DB-per-service, event sourcing)
- Auth architecture (JWT, OAuth2, session-based)
- Multi-tenancy strategy (row-level, schema-level, DB-level)

### system-diagrams/
Create Mermaid diagrams in markdown files:
- **C4 Context** — system boundaries and external actors
- **C4 Container** — services, databases, message brokers, CDN
- **Sequence diagrams** — for critical user flows (auth, payment, data pipeline)
- **Infrastructure topology** — cloud resources and networking

### Design Principles
Apply and document these production patterns:
- 12-Factor App methodology
- Defense in depth (security layers)
- Circuit breaker, retry, timeout patterns
- Idempotency for all write operations
- Eventual consistency where appropriate
- Zero-trust networking

**Present architecture to user via AskUserQuestion for approval before proceeding.**

## Phase 3: Tech Stack Selection

Generate `docs/architecture/tech-stack.md`:

| Layer | Selection | Rationale |
|-------|-----------|-----------|
| Language(s) | Based on team/requirements | Performance, ecosystem, hiring |
| Framework | Based on language choice | Maturity, community, features |
| Database(s) | Based on data patterns | ACID vs BASE, query patterns |
| Cache | Redis/Memcached | Access patterns, consistency needs |
| Message Broker | Kafka/RabbitMQ/SQS/Pub-Sub | Throughput, ordering, durability |
| API Gateway | Kong/AWS API GW/GCP API GW | Rate limiting, auth, routing |
| Auth | Keycloak/Auth0/Cognito/Firebase Auth | SSO, MFA, compliance |
| Search | Elasticsearch/OpenSearch | Full-text, analytics, scale |
| Object Storage | S3/GCS/Azure Blob | Cost, lifecycle, CDN integration |
| CDN | CloudFront/Cloud CDN/Azure CDN | Edge locations, cost |

Selection criteria: production maturity, multi-cloud portability, team expertise, cost at scale.

## Phase 4: API Contract Design

Generate `api/` at the project root:

- **OpenAPI 3.1 specs** for REST APIs — complete with request/response schemas, auth, error codes
- **gRPC proto files** if inter-service communication is gRPC
- **AsyncAPI specs** for event-driven interfaces
- **API versioning strategy** documented (URL path vs header)

Standards enforced:
- Consistent error response format (`{code, message, details, trace_id}`)
- Pagination (`cursor-based` for production, `offset` only for admin)
- Rate limiting headers (`X-RateLimit-*`)
- HATEOAS links where appropriate
- Request ID propagation (`X-Request-ID`)

## Phase 5: Data Model Design

Generate `schemas/` at the project root:

- **ERD diagrams** in Mermaid
- **SQL migration files** (numbered, idempotent)
- **NoSQL collection schemas** (if applicable)
- **Data flow diagrams** — showing how data moves between services
- **Audit trail schema** — who changed what, when

Standards enforced:
- Soft deletes with `deleted_at` timestamps
- UUID primary keys (not auto-increment) for distributed systems
- Created/updated timestamps on all entities
- Tenant isolation at the data layer
- PII field identification and encryption strategy

## Phase 6: Project Scaffolding

Scaffold the project root structure directly. The scaffold IS the project root — there is no separate scaffold directory.

```
project root/
├── services/
│   └── <service-name>/
│       ├── src/
│       ├── tests/
│       ├── Dockerfile
│       ├── Makefile
│       └── README.md
├── libs/
│   └── shared/          # Shared types, utils, clients
├── docker-compose.yml   # Local dev environment
├── Makefile             # Root-level commands
└── README.md            # Getting started guide
```

Each service includes:
- Health check endpoint (`/healthz`, `/readyz`)
- Structured logging (JSON, correlation IDs)
- Graceful shutdown handling
- Configuration from environment variables
- Basic test structure (unit, integration)
- Dockerfile (multi-stage, non-root user, minimal base image)

## Output Structure

### Project Root Output (Deliverables)

```
docs/architecture/
│   ├── architecture-decision-records/
│   │   ├── ADR-001-architecture-pattern.md
│   │   └── ...
│   ├── system-diagrams/
│   │   ├── c4-context.md
│   │   ├── c4-container.md
│   │   └── sequence-*.md
│   ├── tech-stack.md
│   └── design-principles.md
api/
│   ├── openapi/
│   │   └── *.yaml
│   ├── grpc/
│   │   └── *.proto
│   └── asyncapi/
│       └── *.yaml
schemas/
│   ├── erd.md
│   ├── migrations/
│   │   └── *.sql
│   └── data-flow.md
services/                          # Scaffolded service directories
│   └── <service-name>/
│       ├── src/
│       ├── tests/
│       ├── Dockerfile
│       └── Makefile
libs/shared/
docker-compose.yml
Makefile
README.md
```

### Workspace Output (`Claude-Production-Grade-Suite/solution-architect/`)

```
Claude-Production-Grade-Suite/solution-architect/
├── working-notes.md
└── analysis/
    └── *.md
```

## Cloud-Specific Patterns

### AWS
- ECS/EKS for orchestration, RDS/Aurora for relational, DynamoDB for key-value
- SQS/SNS for messaging, CloudWatch for monitoring, Secrets Manager
- VPC with public/private subnets, NAT Gateway, ALB

### GCP
- GKE/Cloud Run for orchestration, Cloud SQL/Spanner for relational, Firestore for document
- Pub/Sub for messaging, Cloud Monitoring, Secret Manager
- VPC with private service access, Cloud Load Balancing

### Azure
- AKS/Container Apps for orchestration, Azure SQL/Cosmos DB for data
- Service Bus for messaging, Azure Monitor, Key Vault
- VNet with subnets, Application Gateway, Front Door

### Multi-Cloud Abstractions
- Use Terraform modules with provider-agnostic interfaces
- Abstract cloud-specific SDKs behind service interfaces
- Document cloud provider mapping in tech-stack.md

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Microservices for a 2-person team | Start modular monolith, extract services when team/scale demands |
| Shared database across services | Each service owns its data, communicate via APIs/events |
| No API versioning strategy | Decide v1 URL path versioning from day one |
| Skipping ADRs | Future-you needs to know WHY, not just WHAT |
| Over-engineering auth | Use managed auth (Auth0/Cognito) unless compliance requires self-hosted |
| Ignoring multi-tenancy from start | Retrofitting tenant isolation is 10x harder than designing it in |
