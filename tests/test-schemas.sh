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

# --- Specific task schema spot checks ---

test_T1_schema_metrics() {
  local schema="$SCHEMAS_DIR/receipt-T1.schema.json"
  local metrics
  metrics=$(jq -r '.required_metrics | sort | join(",")' "$schema")
  assert_eq "T1 requires user_stories, acceptance_criteria" "acceptance_criteria,user_stories" "$metrics"
}

test_T1_schema_min_values() {
  local schema="$SCHEMAS_DIR/receipt-T1.schema.json"
  local us_min
  us_min=$(jq -r '.min_values.user_stories' "$schema")
  assert_eq "T1 min user_stories is 1" "1" "$us_min"
  local ac_min
  ac_min=$(jq -r '.min_values.acceptance_criteria' "$schema")
  assert_eq "T1 min acceptance_criteria is 1" "1" "$ac_min"
}

test_T3a_schema_metrics() {
  local schema="$SCHEMAS_DIR/receipt-T3a.schema.json"
  local metrics
  metrics=$(jq -r '.required_metrics | sort | join(",")' "$schema")
  assert_eq "T3a requires endpoints, services" "endpoints,services" "$metrics"
}

test_T3a_schema_min_services() {
  local schema="$SCHEMAS_DIR/receipt-T3a.schema.json"
  local min
  min=$(jq -r '.min_values.services' "$schema")
  assert_eq "T3a min services is 1" "1" "$min"
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
  # 1 base + 21 task + 3 gate = 25
  assert_eq "25 schema files exist" "25" "$count"
}

# --- Run all tests ---
test_all_schemas_valid_json
test_base_schema_required_fields
test_base_schema_status_enum
test_base_schema_effort_subfields
test_task_schemas_reference_base
test_task_schemas_have_required_metrics
test_T1_schema_metrics
test_T1_schema_min_values
test_T3a_schema_metrics
test_T3a_schema_min_services
test_gate1_schema
test_gate2_schema
test_gate3_schema
test_schema_ids_match_filenames
test_schema_count

print_summary
