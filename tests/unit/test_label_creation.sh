#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SCRIPT_PATH="${SCRIPT_DIR}/../../entrypoint.sh"

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

assert_not_contains() {
  local file_path="$1"
  local unexpected="$2"
  if grep -Fq -- "${unexpected}" "${file_path}"; then
    echo "Assertion failed. Expected not to find: ${unexpected}" >&2
    echo "----- FILE CONTENT -----" >&2
    cat "${file_path}" >&2
    exit 1
  fi
}

setup_case() {
  local case_dir="$1"

  mkdir -p "${case_dir}/bin"
  mkdir -p "${case_dir}/repo"

  cat > "${case_dir}/bin/git" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

args=("$@")
if [[ "${#args[@]}" -ge 2 && "${args[0]}" == "-C" ]]; then
  args=("${args[@]:2}")
fi

if [[ "${#args[@]}" -ge 2 && "${args[0]}" == "config" && "${args[1]}" == "--global" ]]; then
  exit 0
fi

if [[ "${#args[@]}" -ge 1 && "${args[0]}" == "config" ]]; then
  exit 0
fi

if [[ "${#args[@]}" -ge 2 && "${args[0]}" == "remote" && "${args[1]}" == "set-url" ]]; then
  exit 0
fi

if [[ "${#args[@]}" -ge 1 && "${args[0]}" == "fetch" ]]; then
  exit 0
fi

if [[ "${#args[@]}" -ge 2 && "${args[0]}" == "rev-parse" && "${args[1]}" == "--is-inside-work-tree" ]]; then
  echo "true"
  exit 0
fi

if [[ "${#args[@]}" -ge 2 && "${args[0]}" == "show-ref" ]]; then
  last_arg="${args[$((${#args[@]} - 1))]}"
  if [[ "${last_arg}" == "refs/remotes/origin/develop" || "${last_arg}" == "refs/remotes/origin/release/MAPL-v3" ]]; then
    exit 0
  fi
  exit 1
fi

if [[ "${#args[@]}" -ge 2 && "${args[0]}" == "rev-parse" ]]; then
  last_arg="${args[$((${#args[@]} - 1))]}"
  if [[ "${last_arg}" == "origin/develop" ]]; then
    echo "bbb222"
    exit 0
  fi
  if [[ "${last_arg}" == "origin/release/MAPL-v3" ]]; then
    echo "aaa111"
    exit 0
  fi
fi

if [[ "${#args[@]}" -ge 2 && "${args[0]}" == "diff" && "${args[1]}" == "--quiet" ]]; then
  exit 1
fi

if [[ "${#args[@]}" -ge 1 && "${args[0]}" == "diff" ]]; then
  echo "M README.md"
  exit 0
fi

if [[ "${#args[@]}" -ge 1 && "${args[0]}" == "log" ]]; then
  echo "stub log"
  exit 0
fi

if [[ "${#args[@]}" -ge 2 && "${args[0]}" == "symbolic-ref" ]]; then
  echo "develop"
  exit 0
fi

echo "Unsupported git call: $*" >&2
exit 1
EOF

  cat > "${case_dir}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' "$*" >> "${GH_CALLS_LOG}"

if [[ "$#" -ge 3 && "$1" == "api" && "$2" == "--method" && "$3" == "GET" && "$4" == "repos/owner/repo/pulls?state=open&base=release/MAPL-v3" ]]; then
  echo "[]"
  exit 0
fi

if [[ "$#" -ge 2 && "$1" == "api" && "$2" == "repos/owner/repo/labels?per_page=100" ]]; then
  if [[ "${GH_FAIL_ON_LABEL_LOOKUP:-false}" == "true" ]]; then
    echo "Label lookup should not happen in this scenario" >&2
    exit 1
  fi

  if [[ -n "${GH_DYNAMIC_LABEL_STATE:-}" && -f "${GH_DYNAMIC_LABEL_STATE}" ]]; then
    cat "${GH_DYNAMIC_LABEL_STATE}"
  else
    printf '%s\n' "${GH_LABELS_RESPONSE:-[]}"
  fi
  exit 0
fi

if [[ "$#" -ge 3 && "$1" == "api" && "$2" == "--method" && "$3" == "POST" && "$4" == "repos/owner/repo/labels" ]]; then
  label_name=""
  color_value=""
  previous=""
  for arg in "$@"; do
    if [[ "${previous}" == "--raw-field" ]]; then
      case "${arg}" in
        name=*)
          label_name="${arg#name=}"
          ;;
        color=*)
          color_value="${arg#color=}"
          ;;
      esac
    fi
    previous="${arg}"
  done

  printf '%s\n' "${label_name}" >> "${GH_CREATED_LABELS_LOG}"
  if [[ "${color_value}" != "0366d6" ]]; then
    echo "Unexpected label color: ${color_value}" >&2
    exit 1
  fi

  if [[ "${label_name}" == "zzz-race/label" ]]; then
    printf '%s\n' '[{"name":"existing label"},{"name":"zzz-new/feature"},{"name":"zzz-race/label"}]' > "${GH_DYNAMIC_LABEL_STATE}"
    echo "HTTP 422: Validation Failed" >&2
    exit 1
  fi

  exit 0
fi

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "create" ]]; then
  label_values=""
  previous=""
  for arg in "$@"; do
    if [[ "${previous}" == "--label" ]]; then
      label_values+="${arg}"$'\n'
    fi
    previous="${arg}"
  done
  printf '%s' "${label_values}" > "${GH_PR_LABELS_LOG}"
  echo "https://example.test/pr/789"
  exit 0
fi

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "view" ]]; then
  echo "789"
  exit 0
fi

echo "Unsupported gh call: $*" >&2
exit 1
EOF

  cat > "${case_dir}/template.md" <<'EOF'
## Template body from file
EOF

  chmod +x "${case_dir}/bin/git" "${case_dir}/bin/gh"
}

run_case() {
  local case_dir="$1"
  local label_value="$2"
  local create_missing_labels="$3"
  local log_file="$4"

  set +e
  PATH="${case_dir}/bin:${PATH}" \
  GH_CALLS_LOG="${case_dir}/gh-calls.log" \
  GH_CREATED_LABELS_LOG="${case_dir}/gh-created-labels.log" \
  GH_PR_LABELS_LOG="${case_dir}/gh-pr-labels.log" \
  GH_DYNAMIC_LABEL_STATE="${case_dir}/labels-state.json" \
  GITHUB_ACTOR="ci-user" \
  GITHUB_TOKEN="token" \
  GITHUB_REPOSITORY="owner/repo" \
  GITHUB_WORKSPACE="${case_dir}" \
  GITHUB_OUTPUT="${case_dir}/output.txt" \
  INPUT_GITHUB_TOKEN="token" \
  INPUT_REPOSITORY_PATH="repo" \
  INPUT_SOURCE_BRANCH="develop" \
  INPUT_TARGET_BRANCH="release/MAPL-v3" \
  INPUT_TITLE="My PR title" \
  INPUT_TEMPLATE="${case_dir}/template.md" \
  INPUT_BODY="" \
  INPUT_REVIEWER="" \
  INPUT_ASSIGNEE="" \
  INPUT_LABEL="${label_value}" \
  INPUT_CREATE_MISSING_LABELS="${create_missing_labels}" \
  INPUT_MILESTONE="" \
  INPUT_PROJECT="" \
  INPUT_DRAFT="false" \
  INPUT_GET_DIFF="false" \
  INPUT_OLD_STRING="" \
  INPUT_NEW_STRING="" \
  INPUT_IGNORE_USERS="dependabot" \
  INPUT_ALLOW_NO_DIFF="false" \
  INPUT_MAX_BODY_BYTES="65000" \
  INPUT_MAX_DIFF_LINES="0" \
  bash "${SCRIPT_PATH}" >"${log_file}" 2>&1
  status="$?"
  set -e

  if [[ "${status}" != "0" ]]; then
    echo "Expected successful execution" >&2
    cat "${log_file}" >&2
    exit 1
  fi
}

CASE_ONE_DIR="$(mktemp -d)"
CASE_TWO_DIR="$(mktemp -d)"
trap 'rm -rf "${CASE_ONE_DIR}" "${CASE_TWO_DIR}"' EXIT

setup_case "${CASE_ONE_DIR}"
setup_case "${CASE_TWO_DIR}"

: > "${CASE_ONE_DIR}/gh-calls.log"
: > "${CASE_ONE_DIR}/gh-created-labels.log"
: > "${CASE_ONE_DIR}/gh-pr-labels.log"
CASE_ONE_LOG="${CASE_ONE_DIR}/run.log"
run_case "${CASE_ONE_DIR}" "bug,zzz-disabled/label" "false" "${CASE_ONE_LOG}"
assert_not_contains "${CASE_ONE_DIR}/gh-calls.log" "repos/owner/repo/labels?per_page=100"
assert_not_contains "${CASE_ONE_DIR}/gh-calls.log" "repos/owner/repo/labels --raw-field"
assert_contains "${CASE_ONE_DIR}/gh-pr-labels.log" "bug"
assert_contains "${CASE_ONE_DIR}/gh-pr-labels.log" "zzz-disabled/label"

: > "${CASE_TWO_DIR}/gh-calls.log"
: > "${CASE_TWO_DIR}/gh-created-labels.log"
: > "${CASE_TWO_DIR}/gh-pr-labels.log"
printf '%s\n' '[{"name":"existing label"}]' > "${CASE_TWO_DIR}/labels-state.json"
CASE_TWO_LOG="${CASE_TWO_DIR}/run.log"
run_case "${CASE_TWO_DIR}" " existing label , zzz-new/feature , zzz-new/feature , zzz-race/label " "true" "${CASE_TWO_LOG}"

assert_contains "${CASE_TWO_DIR}/gh-calls.log" "api repos/owner/repo/labels?per_page=100 --paginate"
assert_contains "${CASE_TWO_DIR}/gh-calls.log" "api --method POST repos/owner/repo/labels --raw-field name=zzz-new/feature --raw-field color=0366d6"
assert_contains "${CASE_TWO_DIR}/gh-calls.log" "api --method POST repos/owner/repo/labels --raw-field name=zzz-race/label --raw-field color=0366d6"
assert_contains "${CASE_TWO_DIR}/gh-created-labels.log" "zzz-new/feature"
assert_contains "${CASE_TWO_DIR}/gh-created-labels.log" "zzz-race/label"
assert_not_contains "${CASE_TWO_DIR}/gh-created-labels.log" "existing label"
if [[ "$(grep -Fc "zzz-new/feature" "${CASE_TWO_DIR}/gh-created-labels.log")" != "1" ]]; then
  echo "Expected zzz-new/feature to be created once" >&2
  cat "${CASE_TWO_DIR}/gh-created-labels.log" >&2
  exit 1
fi
if [[ "$(grep -Fc "zzz-race/label" "${CASE_TWO_DIR}/gh-created-labels.log")" != "1" ]]; then
  echo "Expected zzz-race/label to be attempted once" >&2
  cat "${CASE_TWO_DIR}/gh-created-labels.log" >&2
  exit 1
fi

assert_contains "${CASE_TWO_LOG}" "[INFO] Label already exists: existing label"
assert_contains "${CASE_TWO_LOG}" "[INFO] Creating missing label: zzz-new/feature"
assert_contains "${CASE_TWO_LOG}" "[INFO] Label became available during creation attempt: zzz-race/label"
assert_contains "${CASE_TWO_DIR}/gh-pr-labels.log" "existing label"
assert_contains "${CASE_TWO_DIR}/gh-pr-labels.log" "zzz-new/feature"
assert_contains "${CASE_TWO_DIR}/gh-pr-labels.log" "zzz-race/label"

create_line="$(grep -n "api --method POST repos/owner/repo/labels --raw-field name=zzz-new/feature --raw-field color=0366d6" "${CASE_TWO_DIR}/gh-calls.log" | head -1 | cut -d: -f1)"
pr_create_line="$(grep -n "^pr create" "${CASE_TWO_DIR}/gh-calls.log" | head -1 | cut -d: -f1)"
if [[ -z "${create_line}" || -z "${pr_create_line}" || "${create_line}" -ge "${pr_create_line}" ]]; then
  echo "Expected label creation to happen before pr create" >&2
  cat "${CASE_TWO_DIR}/gh-calls.log" >&2
  exit 1
fi

echo "Label creation flow test passed."
