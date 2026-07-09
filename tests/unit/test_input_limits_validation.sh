#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SCRIPT_PATH="${SCRIPT_DIR}/../../entrypoint.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

assert_contains() {
  local file_path="$1"
  local expected="$2"
  if ! grep -Fq -- "${expected}" "${file_path}"; then
    echo "Assertion failed. Expected to find: ${expected}" >&2
    echo "----- FILE CONTENT -----" >&2
    cat "${file_path}" >&2
    exit 1
  fi
}

LOG_FILE="${TMP_DIR}/run.log"

run_invalid_case() {
  local draft_value="$1"
  local get_diff_value="$2"
  local allow_no_diff_value="$3"
  local create_missing_labels_value="$4"
  local max_body_bytes_value="$5"
  local expected_message="$6"

  set +e
  GITHUB_ACTOR="ci-user" \
  GITHUB_TOKEN="token" \
  GITHUB_REPOSITORY="owner/repo" \
  GITHUB_WORKSPACE="${TMP_DIR}" \
  GITHUB_OUTPUT="${TMP_DIR}/output.txt" \
  INPUT_GITHUB_TOKEN="token" \
  INPUT_SOURCE_BRANCH="develop" \
  INPUT_TARGET_BRANCH="main" \
  INPUT_TITLE="" \
  INPUT_TEMPLATE="" \
  INPUT_BODY="" \
  INPUT_REVIEWER="" \
  INPUT_ASSIGNEE="" \
  INPUT_LABEL="" \
  INPUT_MILESTONE="" \
  INPUT_DRAFT="${draft_value}" \
  INPUT_GET_DIFF="${get_diff_value}" \
  INPUT_OLD_STRING="" \
  INPUT_NEW_STRING="" \
  INPUT_IGNORE_USERS="dependabot" \
  INPUT_ALLOW_NO_DIFF="${allow_no_diff_value}" \
  INPUT_MAX_BODY_BYTES="${max_body_bytes_value}" \
  INPUT_MAX_DIFF_LINES="0" \
  INPUT_CREATE_MISSING_LABELS="${create_missing_labels_value}" \
  bash "${SCRIPT_PATH}" >"${LOG_FILE}" 2>&1
  STATUS="$?"
  set -e

  if [[ "${STATUS}" == "0" ]]; then
    echo "Expected non-zero exit code for invalid input" >&2
    cat "${LOG_FILE}" >&2
    exit 1
  fi

  assert_contains "${LOG_FILE}" "${expected_message}"
}

run_invalid_case "false" "false" "false" "false" "invalid" "Input 'max_body_bytes' must be a non-negative integer"
run_invalid_case "maybe" "false" "false" "false" "65000" "Input 'draft' must be 'true' or 'false'. Got: maybe"
run_invalid_case "false" "sometimes" "false" "false" "65000" "Input 'get_diff' must be 'true' or 'false'. Got: sometimes"
run_invalid_case "false" "false" "1" "false" "65000" "Input 'allow_no_diff' must be 'true' or 'false'. Got: 1"
run_invalid_case "false" "false" "false" "sure" "65000" "Input 'create_missing_labels' must be 'true' or 'false'. Got: sure"

echo "Input limits validation test passed."
