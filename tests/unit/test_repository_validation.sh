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

set +e
GITHUB_ACTOR="ci-user" \
GITHUB_TOKEN="token" \
GITHUB_REPOSITORY="owner/repo" \
GITHUB_WORKSPACE="${TMP_DIR}" \
GITHUB_OUTPUT="${TMP_DIR}/output.txt" \
INPUT_GITHUB_TOKEN="token" \
INPUT_REPOSITORY="owner/repo;touch /tmp/pwned" \
INPUT_REPOSITORY_PATH="." \
INPUT_SOURCE_BRANCH="develop" \
INPUT_TARGET_BRANCH="main" \
INPUT_TITLE="" \
INPUT_TEMPLATE="" \
INPUT_BODY="" \
INPUT_REVIEWER="" \
INPUT_ASSIGNEE="" \
INPUT_LABEL="" \
INPUT_MILESTONE="" \
INPUT_DRAFT="false" \
INPUT_GET_DIFF="false" \
INPUT_OLD_STRING="" \
INPUT_NEW_STRING="" \
INPUT_IGNORE_USERS="dependabot" \
INPUT_ALLOW_NO_DIFF="false" \
INPUT_MAX_BODY_BYTES="65000" \
INPUT_MAX_DIFF_LINES="0" \
bash "${SCRIPT_PATH}" >"${LOG_FILE}" 2>&1
STATUS="$?"
set -e

if [[ "${STATUS}" == "0" ]]; then
  echo "Expected non-zero exit code for invalid repository input" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

assert_contains "${LOG_FILE}" "Input 'repository' must use owner/name format"

LOG_FILE_DOT_REPO="${TMP_DIR}/run-dot-repo.log"

set +e
GITHUB_ACTOR="ci-user" \
GITHUB_TOKEN="token" \
GITHUB_REPOSITORY="owner/repo" \
GITHUB_WORKSPACE="${TMP_DIR}" \
GITHUB_OUTPUT="${TMP_DIR}/output-dot-repo.txt" \
INPUT_GITHUB_TOKEN="token" \
INPUT_REPOSITORY="owner/.github" \
INPUT_REPOSITORY_PATH="." \
INPUT_SOURCE_BRANCH="develop" \
INPUT_TARGET_BRANCH="main" \
INPUT_TITLE="" \
INPUT_TEMPLATE="" \
INPUT_BODY="" \
INPUT_REVIEWER="" \
INPUT_ASSIGNEE="" \
INPUT_LABEL="" \
INPUT_MILESTONE="" \
INPUT_DRAFT="false" \
INPUT_GET_DIFF="false" \
INPUT_OLD_STRING="" \
INPUT_NEW_STRING="" \
INPUT_IGNORE_USERS="ci-user" \
INPUT_ALLOW_NO_DIFF="false" \
INPUT_MAX_BODY_BYTES="65000" \
INPUT_MAX_DIFF_LINES="0" \
bash "${SCRIPT_PATH}" >"${LOG_FILE_DOT_REPO}" 2>&1
STATUS_DOT_REPO="$?"
set -e

if [[ "${STATUS_DOT_REPO}" != "0" ]]; then
  echo "Expected successful execution for owner/.github repository" >&2
  cat "${LOG_FILE_DOT_REPO}" >&2
  exit 1
fi

assert_contains "${LOG_FILE_DOT_REPO}" "User ci-user is ignored. Skipping."

echo "Repository validation test passed."
