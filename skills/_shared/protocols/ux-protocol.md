# UX Protocol — Single Source of Truth

**Every skill in this plugin MUST follow these 6 rules for ALL user interactions.**

## RULE 1: NEVER Ask Open-Ended Questions

**NEVER output text expecting the user to type.** Every user interaction MUST use `AskUserQuestion` with predefined options. Users navigate with arrow keys (up/down) and press Enter.

**WRONG:** "What do you think?" / "Do you approve?" / "Any feedback?"
**RIGHT:** Use AskUserQuestion with 2-4 options + "Chat about this" as last option.

## RULE 2: "Chat about this" Always Last

Every `AskUserQuestion` MUST have `"Chat about this"` as the last option — the user's escape hatch for free-form typing.

## RULE 3: Recommended Option First

First option = recommended default with `(Recommended)` suffix.

## RULE 4: Continuous Execution

Work continuously until task complete or user presses ESC. Never ask "should I continue?" — just keep going.

## RULE 5: Real-Time Terminal Updates

Constantly print progress. Never go silent. Follow the visual identity protocol at `Claude-Production-Grade-Suite/.protocols/visual-identity.md` for all formatting.

Key rules from visual identity:
- Use `━━━ [Skill Name] ━━━` headers for skill-level sections
- Show numbered phase progress: `[1/5] Phase Name`
- Print `⧖` for in-progress, `✓` for complete, `○` for pending steps
- Every `✓` line must include concrete counts (numbers prove work was done)
- Completion summaries: `✓ [Skill Name]    {metrics with numbers}    ⏱ Xm Ys`

```
━━━ [Skill Name] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [1/N] Phase Name
    ✓ Step completed (247 files scanned, 3 services found)
    ⧖ Step in progress...
    ○ Step pending

  [2/N] Next Phase
    ○ ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## RULE 6: Autonomy Scales with Engagement Mode

Read engagement mode from `Claude-Production-Grade-Suite/.orchestrator/settings.md`. Autonomy scales inversely with engagement level:

| Mode | AskUserQuestion Behavior | Default Posture |
|------|-------------------------|-----------------|
| **Auto** | **ZERO AskUserQuestion calls — ever.** Auto-resolve every decision. Auto-approve every gate. Log all decisions to `auto-decisions.md`. Never block on user input. If uncertain, pick the most common/sensible default and document the reasoning. | Total autonomy. The user walked away. Every decision is yours. |
| **Express** | Zero agent questions. Auto-resolve everything — framework, style, strategy, architecture patterns. Report decisions in output with reasoning. Pipeline gates still fire. | Maximum autonomy. If in doubt, pick the best option and move. |
| **Standard** | 1-2 questions per skill, only for subjective/irreversible choices (visual style, framework when multiple are viable). Auto-resolve everything else. | Lean autonomous. Only ask when the "right answer" genuinely depends on user preference. |
| **Thorough** | Surface all major decisions. Show previews before implementing (design system preview, routing plan, test strategy). | Collaborative. The user is engaged and wants visibility. |
| **Meticulous** | Surface every decision point. User reviews component APIs, design tokens, page layouts before implementation begins. | Full partnership. The user wants to approve each step. |

**The test for whether to ask:** In Auto mode, NEVER ask — resolve and log. In Express mode, would a senior engineer auto-resolve this? If yes, auto-resolve it in Express. Each higher mode widens the circle of what gets surfaced.

**What is NEVER mode-dependent:**
- Pipeline gates (always 3, always fire) — **EXCEPT Auto mode: gates auto-approve**
- Error escalation after 3 failed self-repair attempts — **EXCEPT Auto mode: log and proceed**
- Genuine blockers (missing critical inputs, ambiguous requirements with no reasonable default) — **EXCEPT Auto mode: use best-effort defaults and log**

**What Auto mode changes vs Express:**
- Express still fires 3 pipeline gates requiring user approval. Auto does not.
- Express still escalates after 3 failed self-repair attempts. Auto logs and proceeds.
- Express PM still asks 2-3 interview questions. Auto PM asks zero — derives from request.
- Auto mode always creates an isolated branch. Express does not.
- Auto mode always uses maximum parallelism + worktrees. Express follows user's parallelism choice.

**What is ALWAYS mode-dependent:**
- Framework/library selection
- Visual design choices (style, color, typography)
- Architecture pattern selection (when multiple are viable)
- Test strategy depth
- Documentation scope
