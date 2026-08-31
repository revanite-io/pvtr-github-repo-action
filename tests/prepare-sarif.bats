#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/prepare-sarif.sh"
  RESULTS_DIR="$(mktemp -d)"
  GITHUB_OUTPUT="$(mktemp)"
  export RESULTS_DIR
  export GITHUB_OUTPUT
  export SARIF_ONLY_FAILURES="true"
}

teardown() {
  rm -rf "$RESULTS_DIR"
  rm -f "$GITHUB_OUTPUT"
}

write_mixed_sarif() {
  cat > "$RESULTS_DIR/results.sarif" <<'EOF'
{
  "version": "2.1.0",
  "runs": [
    {
      "tool": { "driver": { "name": "privateer" } },
      "results": [
        { "ruleId": "OSPS-AC-01.01", "level": "error", "message": { "text": "mfa not enforced" } },
        { "ruleId": "OSPS-BR-03.01", "level": "warning", "message": { "text": "All links use HTTPS" } },
        { "ruleId": "OSPS-DO-01.01", "level": "note", "message": { "text": "documentation present" } }
      ]
    }
  ]
}
EOF
}

write_no_failures_sarif() {
  cat > "$RESULTS_DIR/results.sarif" <<'EOF'
{
  "version": "2.1.0",
  "runs": [
    {
      "tool": { "driver": { "name": "privateer" } },
      "results": [
        { "ruleId": "OSPS-BR-03.01", "level": "warning", "message": { "text": "All links use HTTPS" } },
        { "ruleId": "OSPS-DO-01.01", "level": "note", "message": { "text": "documentation present" } }
      ]
    }
  ]
}
EOF
}

output_value() {
  sed -n "s/^$1=//p" "$GITHUB_OUTPUT" | tail -1
}

@test "outputs has_results=false when no sarif file exists" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(output_value has_results)" = "false" ]
  [ -z "$(output_value sarif_file)" ]
}

@test "keeps only error-level results when filtering is enabled" {
  write_mixed_sarif
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(output_value has_results)" = "true" ]
  FILTERED="$(output_value sarif_file)"
  [ "$FILTERED" != "$RESULTS_DIR/results.sarif" ]
  [ "$(jq '[.runs[].results[]] | length' "$FILTERED")" -eq 1 ]
  [ "$(jq -r '.runs[0].results[0].level' "$FILTERED")" = "error" ]
}

@test "original sarif file is left untouched when filtering" {
  write_mixed_sarif
  run bash "$SCRIPT"
  [ "$(jq '[.runs[].results[]] | length' "$RESULTS_DIR/results.sarif")" -eq 3 ]
}

@test "outputs has_results=false when filtering removes all results" {
  write_no_failures_sarif
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(output_value has_results)" = "false" ]
  [ -z "$(output_value sarif_file)" ]
}

@test "explains that no failed controls exist when filtering removes all results" {
  write_no_failures_sarif
  run bash "$SCRIPT"
  [[ "$output" == *"No failed controls"* ]]
}

@test "keeps all results and original file when filtering is disabled" {
  export SARIF_ONLY_FAILURES="false"
  write_mixed_sarif
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(output_value has_results)" = "true" ]
  [ "$(output_value sarif_file)" = "$RESULTS_DIR/results.sarif" ]
  [ "$(jq '[.runs[].results[]] | length' "$RESULTS_DIR/results.sarif")" -eq 3 ]
}

@test "outputs has_results=false for empty results when filtering is disabled" {
  export SARIF_ONLY_FAILURES="false"
  cat > "$RESULTS_DIR/results.sarif" <<'EOF'
{ "version": "2.1.0", "runs": [ { "tool": { "driver": { "name": "privateer" } }, "results": [] } ] }
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(output_value has_results)" = "false" ]
}

@test "handles a run with no results array" {
  cat > "$RESULTS_DIR/results.sarif" <<'EOF'
{ "version": "2.1.0", "runs": [ { "tool": { "driver": { "name": "privateer" } } } ] }
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(output_value has_results)" = "false" ]
}

@test "outputs has_results=false when sarif file is not valid JSON" {
  echo "not json" > "$RESULTS_DIR/results.sarif"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(output_value has_results)" = "false" ]
}
