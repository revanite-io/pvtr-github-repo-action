#!/usr/bin/env bash
set -euo pipefail

# Prepare the scanner's SARIF file for upload to GitHub Code Scanning.
#
# Finds the SARIF file in the results directory, optionally filters it down
# to failed controls only (error-level results), and writes the sarif_file
# and has_results step outputs consumed by the upload step.
#
# Required environment variables:
#   RESULTS_DIR         - Path to the evaluation_results directory (default: evaluation_results)
#   SARIF_ONLY_FAILURES - "true" to keep only error-level (failed control) results
#   GITHUB_OUTPUT       - Path to the GitHub Actions step output file

RESULTS_DIR="${RESULTS_DIR:-evaluation_results}"
SARIF_ONLY_FAILURES="${SARIF_ONLY_FAILURES:-true}"

write_outputs() {
  {
    echo "sarif_file=$1"
    echo "has_results=$2"
  } >> "$GITHUB_OUTPUT"
}

SARIF_FILE=$(find "$RESULTS_DIR" -name "*.sarif" -type f 2>/dev/null | head -1)

if [ -z "$SARIF_FILE" ] || [ ! -f "$SARIF_FILE" ]; then
  echo "⚠️  No SARIF file found in ${RESULTS_DIR} directory"
  write_outputs "" "false"
  exit 0
fi

if ! TOTAL_COUNT=$(jq '[.runs[]?.results[]?] | length' "$SARIF_FILE" 2>/dev/null); then
  echo "⚠️  SARIF file ${SARIF_FILE} is not valid JSON. Skipping upload."
  write_outputs "" "false"
  exit 0
fi

if [ "$SARIF_ONLY_FAILURES" = "true" ]; then
  # Keep only error-level results (failed controls). Needs-review and passed
  # controls never close as Code Scanning alerts, so they stay in the workflow
  # summary and results files instead of the Security tab.
  FILTERED_FILE="${SARIF_FILE%.sarif}.failures.sarif"
  jq '.runs = ((.runs // []) | map(.results = ((.results // []) | map(select(.level == "error")))))' \
    "$SARIF_FILE" > "$FILTERED_FILE"
  SARIF_FILE="$FILTERED_FILE"
  RESULT_COUNT=$(jq '[.runs[]?.results[]?] | length' "$SARIF_FILE")
  echo "Filtered SARIF to failed controls only: kept ${RESULT_COUNT} of ${TOTAL_COUNT} result(s)"
else
  RESULT_COUNT=$TOTAL_COUNT
fi

if [ "$RESULT_COUNT" -gt 0 ]; then
  echo "✅ SARIF file contains ${RESULT_COUNT} result(s)"
  write_outputs "$SARIF_FILE" "true"
elif [ "$SARIF_ONLY_FAILURES" = "true" ] && [ "$TOTAL_COUNT" -gt 0 ]; then
  echo "✅ No failed controls to upload. Skipping Security tab upload; see the workflow summary for passed and needs-review controls."
  write_outputs "" "false"
else
  echo "⚠️  SARIF file exists but contains no results. GitHub Code Scanning requires at least one result."
  write_outputs "" "false"
fi
