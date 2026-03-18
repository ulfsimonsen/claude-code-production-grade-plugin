#!/bin/bash
# Test suite: .claude/settings.json structural correctness & security posture
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/framework.sh"

SETTINGS="$PROJECT_ROOT/.claude/settings.json"

# Helper: check if a jq array contains a value
json_array_contains() {
  local file="$1" path="$2" value="$3"
  jq -e "$path | index(\"$value\") != null" "$file" >/dev/null 2>&1
}

# Helper: get raw JSON content for string matching
settings_raw() {
  cat "$SETTINGS"
}

# ── JSON validity ──────────────────────────────────────────────
begin_suite "Settings — JSON validity"

assert_file_exists "settings.json exists" "$SETTINGS"
assert_json_valid "settings.json is valid JSON" "$SETTINGS"

schema=$(jq -r '.["$schema"] // empty' "$SETTINGS" 2>/dev/null)
assert_eq "\$schema field present" "https://json.schemastore.org/claude-code-settings.json" "$schema"

# ── Sandbox core ───────────────────────────────────────────────
begin_suite "Settings — Sandbox core"

assert_json_field "sandbox.enabled is true" "$SETTINGS" '.sandbox.enabled' "true"
assert_json_field "autoAllowBashIfSandboxed is true" "$SETTINGS" '.sandbox.autoAllowBashIfSandboxed' "true"
assert_json_field "allowUnsandboxedCommands is false" "$SETTINGS" '.sandbox.allowUnsandboxedCommands' "false"

docker_excluded=$(json_array_contains "$SETTINGS" '.sandbox.excludedCommands' 'docker' && echo "yes" || echo "no")
assert_eq "excludedCommands has docker" "yes" "$docker_excluded"

auto_allow=$(jq -r '.sandbox.autoAllow // empty' "$SETTINGS" 2>/dev/null)
assert_eq "no autoAllow field present" "" "$auto_allow"

# ── Network ────────────────────────────────────────────────────
begin_suite "Settings — Network"

hosts_count=$(jq '.sandbox.network.allowedHosts | length' "$SETTINGS" 2>/dev/null)
(( _TOTAL++ ))
if [[ "$hosts_count" -gt 0 ]]; then
  (( _PASS++ )); printf "  \033[32m✓\033[0m allowedHosts present and non-empty (%s entries)\n" "$hosts_count"
else
  (( _FAIL++ )); printf "  \033[31m✗\033[0m allowedHosts present and non-empty\n"
fi

# Field name correctness — must be allowedHosts, not allowedDomains
domains_field=$(jq -r '.sandbox.network.allowedDomains // empty' "$SETTINGS" 2>/dev/null)
assert_eq "uses allowedHosts not allowedDomains" "" "$domains_field"

for domain in "github.com" "api.github.com" "registry.npmjs.org" "context7.com" "api.context7.com"; do
  found=$(json_array_contains "$SETTINGS" '.sandbox.network.allowedHosts' "$domain" && echo "yes" || echo "no")
  assert_eq "allowedHosts has $domain" "yes" "$found"
done

# ── Filesystem — denyRead ──────────────────────────────────────
begin_suite "Settings — Filesystem deny rules"

for path in "~/.ssh" "~/.aws/credentials" "~/.gnupg"; do
  found=$(json_array_contains "$SETTINGS" '.sandbox.filesystem.denyRead' "$path" && echo "yes" || echo "no")
  assert_eq "denyRead has $path" "yes" "$found"
done

for path in "~/.ssh" "~/.aws" "~/.gnupg" "//etc" "//usr"; do
  found=$(json_array_contains "$SETTINGS" '.sandbox.filesystem.denyWrite' "$path" && echo "yes" || echo "no")
  assert_eq "denyWrite has $path" "yes" "$found"
done

# allowWrite must include tmp paths
for path in "//tmp/claude" "//private/tmp/claude"; do
  found=$(json_array_contains "$SETTINGS" '.sandbox.filesystem.allowWrite' "$path" && echo "yes" || echo "no")
  assert_eq "allowWrite has $path" "yes" "$found"
done

# ── Allow list — required tools ────────────────────────────────
begin_suite "Settings — Allow list"

required_tools=("Read" "Edit" "Write" "WebFetch" "WebSearch" "Skill" "ExitPlanMode" "NotebookEdit")
for tool in "${required_tools[@]}"; do
  found=$(json_array_contains "$SETTINGS" '.permissions.allow' "$tool" && echo "yes" || echo "no")
  assert_eq "allow list has $tool" "yes" "$found"
done

# Docker compose rule
docker_rule=$(jq -r '.permissions.allow[] | select(startswith("Bash(docker compose"))' "$SETTINGS" 2>/dev/null)
(( _TOTAL++ ))
if [[ -n "$docker_rule" ]]; then
  (( _PASS++ )); printf "  \033[32m✓\033[0m allow list has docker compose rule\n"
else
  (( _FAIL++ )); printf "  \033[31m✗\033[0m allow list has docker compose rule\n"
fi

# MCP tools
for mcp_tool in "mcp__plugin_context7_context7__resolve-library-id" "mcp__plugin_context7_context7__query-docs"; do
  found=$(json_array_contains "$SETTINGS" '.permissions.allow' "$mcp_tool" && echo "yes" || echo "no")
  assert_eq "allow list has $mcp_tool" "yes" "$found"
done

# No phantom/dead tools
for phantom in "LS" "MultiEdit" "Task"; do
  found=$(json_array_contains "$SETTINGS" '.permissions.allow' "$phantom" && echo "yes" || echo "no")
  assert_eq "allow list does NOT have phantom tool $phantom" "no" "$found"
done

# No redundant tools (auto-allowed, no deny rules)
for redundant in "Glob" "Grep"; do
  found=$(json_array_contains "$SETTINGS" '.permissions.allow' "$redundant" && echo "yes" || echo "no")
  assert_eq "allow list does NOT have redundant tool $redundant" "no" "$found"
done

# ── Deny list — destructive commands ──────────────────────────
begin_suite "Settings — Deny list"

deny_raw=$(jq -r '.permissions.deny[]' "$SETTINGS" 2>/dev/null)

for pattern in "Bash(rm -rf *)" "Bash(rm -f *)" "Bash(sudo *)" "Bash(chmod 777 *)" "Bash(chown *)" "Bash(dd *)" "Bash(mkfs*)"; do
  found=$(json_array_contains "$SETTINGS" '.permissions.deny' "$pattern" && echo "yes" || echo "no")
  assert_eq "deny list has $pattern" "yes" "$found"
done

# Sensitive read denials
for pattern in "Read(**/.env)" "Read(**/.env.*)" "Read(**/*.pem)" "Read(**/*.key)" "Read(~/.ssh/**)"; do
  found=$(json_array_contains "$SETTINGS" '.permissions.deny' "$pattern" && echo "yes" || echo "no")
  assert_eq "deny list has $pattern" "yes" "$found"
done

# ── Summary ────────────────────────────────────────────────────
print_summary
