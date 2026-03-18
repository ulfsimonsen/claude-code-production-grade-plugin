# ADR-002: MCP Elicitation Migration Strategy

**Status:** Accepted
**Context:** US-3 requires replacing ALL AskUserQuestion calls across 14 skills with MCP Elicitation. The UX Protocol (ux-protocol.md) currently defines 6 rules around AskUserQuestion.

**Decision:** New 9th shared protocol (`elicitation-protocol.md`) replaces Rules 1-3 in UX Protocol. UX Protocol retains Rules 4-6 (continuous execution, real-time progress, autonomy scaling) as they apply regardless of input mechanism.

## Architecture

### New Protocol: `skills/_shared/protocols/elicitation-protocol.md`

Replaces AskUserQuestion-specific guidance with Elicitation equivalents:
- Rule 1: All user input via MCP Elicitation (structured forms, not open-ended text)
- Rule 2: Every form includes a free-form text field as escape hatch
- Rule 3: Recommended option presented first with `(Recommended)` suffix
- Mapping guide: AskUserQuestion options → Elicitation form fields
- Schema reference for common patterns (single-select, multi-select, text input, numeric input)

### Migration Scope

| File Category | Count | Changes |
|---|---|---|
| UX Protocol | 1 | Remove Rules 1-3, add pointer to elicitation-protocol.md |
| Skill SKILL.md files | 14 | Replace `AskUserQuestion` references with Elicitation |
| Phase dispatchers (define/build/harden/ship/sustain) | 5 | Replace gate ceremony AskUserQuestion calls |
| Orchestrator SKILL.md | 1 | Replace mode selection, engagement mode, parallelism questions |

### Hook Integration

New hooks in hooks.json:
- `PreToolUse` matcher `Elicitation` → `hooks/elicitation-validator.sh` — validates elicitation forms before display
- `PostToolUse` matcher `ElicitationResult` → (optional) transform/log user responses

### UX Protocol Update

```
Rules 1-3: REMOVED (replaced by elicitation-protocol.md)
Rule 4: Continuous Execution (unchanged)
Rule 5: Real-Time Terminal Updates (unchanged)
Rule 6: Autonomy Scales with Engagement Mode (unchanged — Auto mode still means zero input)
```

**Consequences:**
- All 14 skills load 9 protocols instead of 8 at startup (marginal token cost)
- AskUserQuestion is fully deprecated in the plugin — no hybrid state
- Gate ceremonies gain richer form capabilities (grouped fields, validation)
- Auto mode behavior unchanged — zero Elicitation calls, same as zero AskUserQuestion calls

**Alternatives Considered:**
- Update UX Protocol in-place: Rejected — UX Protocol handles more than just input (Rules 4-6). Cleaner to separate input concerns into own protocol.
- Wrapper pattern: Rejected — adds abstraction layer without benefit. Direct Elicitation calls are clearer.
