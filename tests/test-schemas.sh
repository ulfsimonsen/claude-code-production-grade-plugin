#!/bin/bash
# Tests for skills/production-grade/schemas/*.json
source "$(dirname "$0")/framework.sh"

begin_suite "JSON Schemas"

# --- All schemas are valid JSON ---

test_all_schemas_valid_json() {
  local failed=0
  for schema in "$SCHEMAS_DIR"/*.json; do
    local name
    name=$(basename "$schema")
    if ! jq empty "$schema" 2>/dev/null; then
      ((_TOTAL++)); ((_FAIL++))
      printf "  \033[31m✗\033[0m %s is valid JSON\n" "$name"
      failed=1
    fi
  done
  if [[ $failed -eq 0 ]]; then
    local count
    count=$(ls "$SCHEMAS_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m all %s schemas are valid JSON\n" "$count"
  fi
}

# --- Base schema structure ---

test_base_schema_required_fields() {
  local base="$SCHEMAS_DIR/receipt-base.schema.json"
  local required
  required=$(jq -r '.required | sort | join(",")' "$base")
  assert_eq "base schema has 7 required fields" "artifacts,completed_at,effort,metrics,skill,status,task_id" "$required"
}

test_base_schema_status_enum() {
  local base="$SCHEMAS_DIR/receipt-base.schema.json"
  local enum
  enum=$(jq -r '.properties.status.enum | sort | join(",")' "$base")
  assert_eq "base schema status enum" "completed,failed,skipped" "$enum"
}

test_base_schema_effort_subfields() {
  local base="$SCHEMAS_DIR/receipt-base.schema.json"
  local required
  required=$(jq -r '.properties.effort.required | sort | join(",")' "$base")
  assert_eq "base schema effort required sub-fields" "files_read,files_written,tool_calls" "$required"
}

# --- Task schemas reference base ---

test_task_schemas_reference_base() {
  local all_ref=true
  for schema in "$SCHEMAS_DIR"/receipt-T*.json; do
    local name ref
    name=$(basename "$schema")
    ref=$(jq -r '."$ref" // empty' "$schema")
    if [[ "$ref" != "receipt-base.schema.json" ]]; then
      ((_TOTAL++)); ((_FAIL++))
      printf "  \033[31m✗\033[0m %s references base schema (got: '%s')\n" "$name" "$ref"
      all_ref=false
    fi
  done
  if [[ "$all_ref" == "true" ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m all task schemas reference receipt-base.schema.json\n"
  fi
}

# --- Task schemas have required_metrics ---

test_task_schemas_have_required_metrics() {
  local missing=""
  for schema in "$SCHEMAS_DIR"/receipt-T*.json; do
    local name
    name=$(basename "$schema")
    if ! jq -e '.required_metrics' "$schema" >/dev/null 2>&1; then
      missing="${missing} ${name}"
    fi
  done
  if [[ -z "$missing" ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m all task schemas have required_metrics\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m task schemas missing required_metrics:%s\n" "$missing"
  fi
}

# --- Per-task schema required_metrics validation ---
# Helper: assert a task schema has the expected required_metrics
assert_task_metrics() {
  local task_id="$1" expected_sorted="$2"
  local schema="$SCHEMAS_DIR/receipt-${task_id}.schema.json"
  local metrics
  metrics=$(jq -r '.required_metrics | sort | join(",")' "$schema" 2>/dev/null)
  assert_eq "${task_id} requires ${expected_sorted}" "$expected_sorted" "$metrics"
}

# Helper: assert a task schema has a min_value for a given metric
assert_task_min_value() {
  local task_id="$1" metric="$2" expected="$3"
  local schema="$SCHEMAS_DIR/receipt-${task_id}.schema.json"
  local actual
  actual=$(jq -r ".min_values.${metric}" "$schema" 2>/dev/null)
  assert_eq "${task_id} min ${metric} is ${expected}" "$expected" "$actual"
}

test_T1_schema() {
  assert_task_metrics "T1" "acceptance_criteria,user_stories"
  assert_task_min_value "T1" "user_stories" "1"
  assert_task_min_value "T1" "acceptance_criteria" "1"
}

test_T2_schema() {
  assert_task_metrics "T2" "adrs,endpoints"
  assert_task_min_value "T2" "adrs" "1"
  assert_task_min_value "T2" "endpoints" "1"
}

test_T3a_schema() {
  assert_task_metrics "T3a" "endpoints,services"
  assert_task_min_value "T3a" "services" "1"
}

test_T3b_schema() {
  assert_task_metrics "T3b" "components,pages"
  assert_task_min_value "T3b" "pages" "1"
}

test_T4a_schema() {
  assert_task_metrics "T4a" "dockerfiles"
}

test_T4b_schema() {
  assert_task_metrics "T4b" "containers"
  assert_task_min_value "T4b" "containers" "1"
}

test_T5a_schema() {
  assert_task_metrics "T5a" "test_scenarios"
}

test_T5b_schema() {
  assert_task_metrics "T5b" "passing,tests"
  assert_task_min_value "T5b" "tests" "1"
}

test_T6a_schema() {
  assert_task_metrics "T6a" "threats_identified"
}

test_T6b_schema() {
  assert_task_metrics "T6b" "checklist_items"
}

test_T6c_schema() {
  assert_task_metrics "T6c" "critical,findings,high"
  assert_task_min_value "T6c" "findings" "0"
  assert_task_min_value "T6c" "critical" "0"
}

test_T6d_schema() {
  assert_task_metrics "T6d" "findings"
  assert_task_min_value "T6d" "findings" "0"
}

test_T7_schema() {
  assert_task_metrics "T7" "ci_workflows,terraform_modules"
}

test_T8_schema() {
  assert_task_metrics "T8" "critical_fixed,high_fixed"
  assert_task_min_value "T8" "critical_fixed" "0"
  assert_task_min_value "T8" "high_fixed" "0"
}

test_T9a_schema() {
  assert_task_metrics "T9a" "slos"
}

test_T9b_schema() {
  assert_task_metrics "T9b" "alerts,runbooks,slos"
  assert_task_min_value "T9b" "slos" "1"
}

test_T10_schema() {
  assert_task_metrics "T10" "optimizations"
}

test_T11a_schema() {
  assert_task_metrics "T11a" "api_docs"
}

test_T11b_schema() {
  assert_task_metrics "T11b" "ops_docs"
}

test_T12_schema() {
  assert_task_metrics "T12" "skills"
  assert_task_min_value "T12" "skills" "0"
}

test_T13_schema() {
  assert_task_metrics "T13" "files_assembled"
  assert_task_min_value "T13" "files_assembled" "0"
}

# --- Gate schemas ---

test_gate1_schema() {
  local schema="$SCHEMAS_DIR/gate1.schema.json"
  assert_json_valid "gate1.schema.json is valid JSON" "$schema"
  local receipts
  receipts=$(jq -r '.receipts_required | join(",")' "$schema")
  assert_eq "gate1 requires T1 receipt" "T1" "$receipts"
}

test_gate2_schema() {
  local schema="$SCHEMAS_DIR/gate2.schema.json"
  assert_json_valid "gate2.schema.json is valid JSON" "$schema"
  local receipts
  receipts=$(jq -r '.receipts_required | sort | join(",")' "$schema")
  assert_eq "gate2 requires T1 and T2 receipts" "T1,T2" "$receipts"
}

test_gate3_schema() {
  local schema="$SCHEMAS_DIR/gate3.schema.json"
  assert_json_valid "gate3.schema.json is valid JSON" "$schema"
  local count
  count=$(jq -r '.receipts_required | length' "$schema")
  # Gate 3 should require multiple receipts (all build/harden/ship tasks)
  assert_eq "gate3 requires multiple receipts" "true" "$( [ "$count" -gt 2 ] && echo true || echo false )"
}

# --- Schema ID matches filename ---

test_schema_ids_match_filenames() {
  local mismatches=""
  for schema in "$SCHEMAS_DIR"/*.json; do
    local name expected_id actual_id
    name=$(basename "$schema")
    expected_id="$name"
    actual_id=$(jq -r '."$id" // empty' "$schema")
    if [[ -n "$actual_id" && "$actual_id" != "$expected_id" ]]; then
      mismatches="${mismatches} ${name}(id=${actual_id})"
    fi
  done
  if [[ -z "$mismatches" ]]; then
    ((_TOTAL++)); ((_PASS++))
    printf "  \033[32m✓\033[0m all schema \$id fields match filenames\n"
  else
    ((_TOTAL++)); ((_FAIL++))
    printf "  \033[31m✗\033[0m schema ID mismatches:%s\n" "$mismatches"
  fi
}

# --- Expected schema count ---

test_schema_count() {
  local count
  count=$(ls "$SCHEMAS_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
  # 1 base + 21 task + 3 gate + 1 iteration = 26
  assert_eq "26 schema files exist" "26" "$count"
}

# --- Run all tests ---
test_all_schemas_valid_json
test_base_schema_required_fields
test_base_schema_status_enum
test_base_schema_effort_subfields
test_task_schemas_reference_base
test_task_schemas_have_required_metrics
test_T1_schema
test_T2_schema
test_T3a_schema
test_T3b_schema
test_T4a_schema
test_T4b_schema
test_T5a_schema
test_T5b_schema
test_T6a_schema
test_T6b_schema
test_T6c_schema
test_T6d_schema
test_T7_schema
test_T8_schema
test_T9a_schema
test_T9b_schema
test_T10_schema
test_T11a_schema
test_T11b_schema
test_T12_schema
test_T13_schema
test_gate1_schema
test_gate2_schema
test_gate3_schema
test_schema_ids_match_filenames
test_schema_count

print_summary
