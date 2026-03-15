#!/bin/bash
# Tests for Auto mode structural consistency across all skill/phase/protocol files
# Validates that Auto mode instructions are present, consistent, and complete
source "$(dirname "$0")/framework.sh"

SKILLS_DIR="$PROJECT_ROOT/skills/production-grade"
PHASES_DIR="$SKILLS_DIR/phases"
PROTOCOLS_DIR="$PROJECT_ROOT/skills/_shared/protocols"

begin_suite "Auto Mode — Structural Consistency"

# Helper: check if a file contains a string (grep-based, no cat)
assert_file_contains() {
  local desc="$1" file="$2" needle="$3"
  ((_TOTAL++))
  if grep -qF "$needle" "$file" 2>/dev/null; then
    ((_PASS++))
    printf "  \033[32m✓\033[0m %s\n" "$desc"
  else
    ((_FAIL++))
    printf "  \033[31m✗\033[0m %s\n" "$desc"
    printf "    '%s' not found in %s\n" "$needle" "$(basename "$file")"
  fi
}

# Helper: count occurrences of a pattern in a file
count_in_file() {
  grep -cF "$2" "$1" 2>/dev/null || echo 0
}

# ─── SKILL.md: Auto mode exists in request classification ───

test_skillmd_auto_in_classification_table() {
  assert_file_contains "SKILL.md has Auto in request classification table" \
    "$SKILLS_DIR/SKILL.md" '| **Auto**'
}

test_skillmd_auto_trigger_signals() {
  assert_file_contains "SKILL.md lists Auto trigger signals" \
    "$SKILLS_DIR/SKILL.md" '"auto", "autonomous"'
}

test_skillmd_auto_in_engagement_options() {
  assert_file_contains "SKILL.md has Auto in engagement mode options" \
    "$SKILLS_DIR/SKILL.md" 'Auto — fully autonomous'
}

test_skillmd_auto_mode_pipeline_section() {
  assert_file_contains "SKILL.md has Auto Mode Pipeline section" \
    "$SKILLS_DIR/SKILL.md" '## Auto Mode Pipeline'
}

test_skillmd_auto_in_partial_execution() {
  assert_file_contains "SKILL.md has /production-grade auto in partial execution" \
    "$SKILLS_DIR/SKILL.md" '/production-grade auto'
}

test_skillmd_auto_in_common_mistakes() {
  assert_file_contains "SKILL.md has Auto mode in common mistakes" \
    "$SKILLS_DIR/SKILL.md" 'In Auto mode: NEVER call AskUserQuestion'
}

# ─── SKILL.md: Auto Mode Pipeline subsections ───

test_skillmd_auto_permissions_preflight() {
  assert_file_contains "Auto pipeline has permissions pre-flight" \
    "$SKILLS_DIR/SKILL.md" 'Permissions Pre-Flight'
}

test_skillmd_auto_branch_isolation() {
  assert_file_contains "Auto pipeline has branch isolation" \
    "$SKILLS_DIR/SKILL.md" 'Branch Isolation'
}

test_skillmd_auto_configure_settings() {
  assert_file_contains "Auto pipeline has auto-configure settings" \
    "$SKILLS_DIR/SKILL.md" 'Auto-Configure Settings'
}

test_skillmd_auto_dashboard() {
  assert_file_contains "Auto pipeline has dashboard step" \
    "$SKILLS_DIR/SKILL.md" 'Print Auto Mode Dashboard'
}

test_skillmd_auto_bootstrap_execute() {
  assert_file_contains "Auto pipeline has bootstrap + execute" \
    "$SKILLS_DIR/SKILL.md" 'Bootstrap + Execute'
}

test_skillmd_auto_final_summary() {
  assert_file_contains "Auto pipeline has final summary additions" \
    "$SKILLS_DIR/SKILL.md" 'Auto Mode — Final Summary Additions'
}

test_skillmd_auto_cleanup() {
  assert_file_contains "Auto pipeline has cleanup section" \
    "$SKILLS_DIR/SKILL.md" 'Auto Mode — Cleanup'
}

# ─── SKILL.md: Auto Mode override table ───

test_skillmd_auto_override_gate1() {
  assert_file_contains "Override table covers Gate 1" \
    "$SKILLS_DIR/SKILL.md" '| **Gate 1** (BRD Approval) |'
}

test_skillmd_auto_override_gate2() {
  assert_file_contains "Override table covers Gate 2" \
    "$SKILLS_DIR/SKILL.md" '| **Gate 2** (Architecture Approval) |'
}

test_skillmd_auto_override_gate3() {
  assert_file_contains "Override table covers Gate 3" \
    "$SKILLS_DIR/SKILL.md" '| **Gate 3** (Production Readiness) |'
}

test_skillmd_auto_override_brownfield() {
  assert_file_contains "Override table covers brownfield detection" \
    "$SKILLS_DIR/SKILL.md" '| **Brownfield detection**'
}

test_skillmd_auto_override_assembly() {
  assert_file_contains "Override table covers assembly question" \
    "$SKILLS_DIR/SKILL.md" '| **Assembly question**'
}

# ─── SKILL.md: Settings format includes auto ───

test_skillmd_settings_format_includes_auto() {
  assert_file_contains "Settings format shows auto as engagement option" \
    "$SKILLS_DIR/SKILL.md" 'Engagement: [auto|express|standard|thorough|meticulous]'
}

# ─── define.md: Auto mode sections ───

test_define_t1_auto_mode() {
  assert_file_contains "define.md T1 has Auto Mode Behavior section" \
    "$PHASES_DIR/define.md" '### Auto Mode Behavior'
}

test_define_t1_auto_uses_agent_not_skill() {
  assert_file_contains "define.md T1 auto uses Agent (not Skill)" \
    "$PHASES_DIR/define.md" 'Product Manager operating in AUTO MODE'
}

test_define_t1_auto_no_askuserquestion() {
  assert_file_contains "define.md T1 auto says no AskUserQuestion" \
    "$PHASES_DIR/define.md" 'DO NOT use AskUserQuestion'
}

test_define_t2_auto_mode() {
  assert_file_contains "define.md T2 has Auto Mode Behavior section" \
    "$PHASES_DIR/define.md" 'Solution Architect operating in AUTO MODE'
}

test_define_gate1_auto_approve() {
  assert_file_contains "define.md Gate 1 has auto-approve section" \
    "$PHASES_DIR/define.md" 'Auto Mode — Gate 1 Auto-Approve'
}

test_define_gate1_auto_approved_label() {
  assert_file_contains "define.md Gate 1 has AUTO-APPROVED label" \
    "$PHASES_DIR/define.md" 'Requirements Approval  [AUTO-APPROVED]'
}

test_define_gate2_auto_approve() {
  assert_file_contains "define.md Gate 2 has auto-approve section" \
    "$PHASES_DIR/define.md" 'Auto Mode — Gate 2 Auto-Approve'
}

test_define_gate2_auto_approved_label() {
  assert_file_contains "define.md Gate 2 has AUTO-APPROVED label" \
    "$PHASES_DIR/define.md" 'Architecture Approval  [AUTO-APPROVED]'
}

test_define_standard_gate1_label() {
  assert_file_contains "define.md has Standard Mode label for Gate 1" \
    "$PHASES_DIR/define.md" 'Standard Mode — Gate 1 (non-Auto)'
}

test_define_standard_gate2_label() {
  assert_file_contains "define.md has Standard Mode label for Gate 2" \
    "$PHASES_DIR/define.md" 'Standard Mode — Gate 2 (non-Auto)'
}

test_define_auto_in_common_mistakes() {
  assert_file_contains "define.md common mistakes covers Auto mode" \
    "$PHASES_DIR/define.md" 'Calling AskUserQuestion in Auto mode'
}

test_define_auto_skill_mistake() {
  assert_file_contains "define.md common mistakes covers Skill vs Agent" \
    "$PHASES_DIR/define.md" 'Invoking PM/Architect Skills in Auto mode'
}

# ─── build.md: Auto mode sections ───

test_build_worktree_auto_commit() {
  assert_file_contains "build.md worktree pre-flight handles Auto mode" \
    "$PHASES_DIR/build.md" 'Engagement: auto'
}

test_build_auto_commit_command() {
  assert_file_contains "build.md auto-commits in Auto mode" \
    "$PHASES_DIR/build.md" 'auto: pre-Wave A checkpoint'
}

test_build_frontend_style_auto() {
  assert_file_contains "build.md frontend style handles Auto/Express" \
    "$PHASES_DIR/build.md" 'Auto/Express: auto-select best style'
}

test_build_failure_auto_mode() {
  assert_file_contains "build.md failure handling covers Auto mode" \
    "$PHASES_DIR/build.md" 'Auto mode: log failure'
}

# ─── ship.md: Auto mode sections ───

test_ship_gate3_auto_approve() {
  assert_file_contains "ship.md Gate 3 has auto-approve section" \
    "$PHASES_DIR/ship.md" 'Auto Mode — Gate 3 Auto-Approve'
}

test_ship_gate3_auto_approved_label() {
  assert_file_contains "ship.md Gate 3 has AUTO-APPROVED label" \
    "$PHASES_DIR/ship.md" 'Production Readiness  [AUTO-APPROVED]'
}

test_ship_gate3_standard_mode_label() {
  assert_file_contains "ship.md has Standard Mode label for Gate 3" \
    "$PHASES_DIR/ship.md" 'Standard Mode — Gate 3 (non-Auto)'
}

test_ship_gate3_auto_no_rework() {
  assert_file_contains "ship.md auto-approve skips rework loops" \
    "$PHASES_DIR/ship.md" 'No rework loops'
}

# ─── sustain.md: Auto mode sections ───

test_sustain_auto_assembly() {
  assert_file_contains "sustain.md has Auto Mode Assembly section" \
    "$PHASES_DIR/sustain.md" 'Auto Mode Assembly'
}

test_sustain_auto_integrate() {
  assert_file_contains "sustain.md auto-integrates to project root" \
    "$PHASES_DIR/sustain.md" 'Auto: integrated all code to project root'
}

test_sustain_standard_assembly_label() {
  assert_file_contains "sustain.md has Standard Mode Assembly label" \
    "$PHASES_DIR/sustain.md" 'Standard Mode Assembly (non-Auto)'
}

test_sustain_auto_no_branch_switch() {
  assert_file_contains "sustain.md says not to switch branches in Auto" \
    "$PHASES_DIR/sustain.md" 'Do NOT switch branches'
}

# ─── ux-protocol.md: Auto mode in engagement table ───

test_ux_protocol_auto_row() {
  assert_file_contains "ux-protocol.md has Auto row in engagement table" \
    "$PROTOCOLS_DIR/ux-protocol.md" '| **Auto**'
}

test_ux_protocol_auto_zero_calls() {
  assert_file_contains "ux-protocol.md Auto row says ZERO AskUserQuestion" \
    "$PROTOCOLS_DIR/ux-protocol.md" 'ZERO AskUserQuestion calls'
}

test_ux_protocol_auto_vs_express() {
  assert_file_contains "ux-protocol.md documents Auto vs Express differences" \
    "$PROTOCOLS_DIR/ux-protocol.md" 'What Auto mode changes vs Express'
}

test_ux_protocol_auto_gate_exception() {
  assert_file_contains "ux-protocol.md notes Auto gate exception" \
    "$PROTOCOLS_DIR/ux-protocol.md" 'EXCEPT Auto mode: gates auto-approve'
}

# ─── Cross-file consistency: auto-decisions.md path ───

test_auto_decisions_path_consistency() {
  local files_with_ref=0
  for file in "$SKILLS_DIR/SKILL.md" "$PHASES_DIR/define.md" "$PHASES_DIR/sustain.md" "$PHASES_DIR/ship.md"; do
    if grep -qF 'auto-decisions.md' "$file" 2>/dev/null; then
      ((files_with_ref++))
    fi
  done
  assert_eq "auto-decisions.md referenced in 4+ files" "true" "$( [ "$files_with_ref" -ge 4 ] && echo true || echo false )"
}

# ─── Cross-file consistency: Engagement: auto check ───

test_all_phase_files_check_engagement_auto() {
  local missing=""
  for phase in define build ship sustain; do
    if ! grep -qF 'Engagement: auto' "$PHASES_DIR/${phase}.md" 2>/dev/null; then
      missing="${missing} ${phase}.md"
    fi
  done
  if [[ -z "$missing" ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m all 4 phase dispatchers check Engagement: auto\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m phase dispatchers missing Engagement: auto check:%s\n" "$missing"
  fi
}

# ─── Cross-file consistency: every gate has AUTO-APPROVED ───

test_all_gates_have_auto_approved() {
  local gate12_count gate3_count
  gate12_count=$(grep -cF 'AUTO-APPROVED' "$PHASES_DIR/define.md" 2>/dev/null || echo 0)
  gate3_count=$(grep -cF 'AUTO-APPROVED' "$PHASES_DIR/ship.md" 2>/dev/null || echo 0)
  # define.md has Gate 1 + Gate 2 (at least 2 occurrences), ship.md has Gate 3 (at least 1)
  local result
  result=$( [ "$gate12_count" -ge 2 ] && [ "$gate3_count" -ge 1 ] && echo "true" || echo "false" )
  assert_eq "all 3 gates have AUTO-APPROVED ceremony (define:${gate12_count} ship:${gate3_count})" "true" "$result"
}

# ─── Cross-file consistency: Auto branch naming ───

test_auto_branch_naming_pattern() {
  assert_file_contains "SKILL.md uses auto/production-grade/ branch prefix" \
    "$SKILLS_DIR/SKILL.md" 'auto/production-grade/'
}

# ─── Completeness: Auto mode dashboard ───

test_auto_dashboard_label() {
  assert_file_contains "Auto dashboard has AUTO MODE label" \
    "$SKILLS_DIR/SKILL.md" 'AUTO MODE'
}

test_auto_dashboard_zero_interaction() {
  assert_file_contains "Auto dashboard states zero interaction" \
    "$SKILLS_DIR/SKILL.md" 'Interaction: ZERO'
}

# ─── Completeness: Auto mode final summary ───

test_auto_final_summary_label() {
  assert_file_contains "Auto final summary has AUTO COMPLETE label" \
    "$SKILLS_DIR/SKILL.md" 'AUTO COMPLETE'
}

test_auto_final_summary_has_decisions_log() {
  assert_file_contains "Auto final summary has decisions log section" \
    "$SKILLS_DIR/SKILL.md" 'Auto Decisions Log'
}

test_auto_final_summary_has_known_issues() {
  assert_file_contains "Auto final summary has known issues section" \
    "$SKILLS_DIR/SKILL.md" 'Known Issues (unresolved)'
}

test_auto_final_summary_has_branch_merge_instructions() {
  assert_file_contains "Auto final summary has merge instructions" \
    "$SKILLS_DIR/SKILL.md" 'git checkout main && git merge'
}

# ─── Run all tests ───
test_skillmd_auto_in_classification_table
test_skillmd_auto_trigger_signals
test_skillmd_auto_in_engagement_options
test_skillmd_auto_mode_pipeline_section
test_skillmd_auto_in_partial_execution
test_skillmd_auto_in_common_mistakes
test_skillmd_auto_permissions_preflight
test_skillmd_auto_branch_isolation
test_skillmd_auto_configure_settings
test_skillmd_auto_dashboard
test_skillmd_auto_bootstrap_execute
test_skillmd_auto_final_summary
test_skillmd_auto_cleanup
test_skillmd_auto_override_gate1
test_skillmd_auto_override_gate2
test_skillmd_auto_override_gate3
test_skillmd_auto_override_brownfield
test_skillmd_auto_override_assembly
test_skillmd_settings_format_includes_auto
test_define_t1_auto_mode
test_define_t1_auto_uses_agent_not_skill
test_define_t1_auto_no_askuserquestion
test_define_t2_auto_mode
test_define_gate1_auto_approve
test_define_gate1_auto_approved_label
test_define_gate2_auto_approve
test_define_gate2_auto_approved_label
test_define_standard_gate1_label
test_define_standard_gate2_label
test_define_auto_in_common_mistakes
test_define_auto_skill_mistake
test_build_worktree_auto_commit
test_build_auto_commit_command
test_build_frontend_style_auto
test_build_failure_auto_mode
test_ship_gate3_auto_approve
test_ship_gate3_auto_approved_label
test_ship_gate3_standard_mode_label
test_ship_gate3_auto_no_rework
test_sustain_auto_assembly
test_sustain_auto_integrate
test_sustain_standard_assembly_label
test_sustain_auto_no_branch_switch
test_ux_protocol_auto_row
test_ux_protocol_auto_zero_calls
test_ux_protocol_auto_vs_express
test_ux_protocol_auto_gate_exception
test_auto_decisions_path_consistency
test_all_phase_files_check_engagement_auto
test_all_gates_have_auto_approved
test_auto_branch_naming_pattern
test_auto_dashboard_label
test_auto_dashboard_zero_interaction
test_auto_final_summary_label
test_auto_final_summary_has_decisions_log
test_auto_final_summary_has_known_issues
test_auto_final_summary_has_branch_merge_instructions

print_summary
