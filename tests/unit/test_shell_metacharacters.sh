#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SCRIPT_PATH="${SCRIPT_DIR}/../../entrypoint.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

assert_arg() {
  local expected="$1"
  if ! grep -Fxq -- "${expected}" "${TMP_DIR}/gh.args"; then
    echo "Assertion failed. Expected gh to receive literal argument: ${expected}" >&2
    echo "----- GH ARGS -----" >&2
    cat "${TMP_DIR}/gh.args" >&2
    exit 1
  fi
}

assert_no_marker() {
  local leaked
  leaked="$(find "${TMP_DIR}" -maxdepth 1 -name 'pwned-*' -print)"
  if [[ -n "${leaked}" ]]; then
    echo "Assertion failed. Injected command was executed: ${leaked}" >&2
    exit 1
  fi
}

mkdir -p "${TMP_DIR}/bin" "${TMP_DIR}/repo"

cat > "${TMP_DIR}/bin/git" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

args=("$@")
if [[ "${#args[@]}" -ge 2 && "${args[0]}" == "-C" ]]; then
  args=("${args[@]:2}")
fi

case "${args[0]}" in
  config|remote|fetch|show-ref) exit 0 ;;
  rev-parse)
    if [[ "${args[1]}" == "--is-inside-work-tree" ]]; then
      echo "true"
    else
      echo "${args[$((${#args[@]} - 1))]}"
    fi
    exit 0
    ;;
  diff)
    if [[ "${args[1]:-}" == "--quiet" ]]; then
      exit 1
    fi
    echo "M README.md"
    exit 0
    ;;
  log)
    echo "stub log"
    exit 0
    ;;
esac

echo "Unsupported git call: $*" >&2
exit 1
EOF

cat > "${TMP_DIR}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

{
  echo "--- gh call"
  printf '%s\n' "$@"
} >> "${GH_ARGS_FILE}"

if [[ "$1" == "api" && "$2" == "--method" && "$3" == "GET" && "$4" == repos/owner/repo/pulls\?state=open* ]]; then
  if [[ "${STUB_EXISTING_PR}" == "true" ]]; then
    jq -n --arg ref "${INPUT_SOURCE_BRANCH}" \
      '[{number: 7, head: {ref: $ref, repo: {full_name: "owner/repo"}}}]'
  else
    echo "[]"
  fi
  exit 0
fi

if [[ "$1" == "api" && "$2" == "--method" && "$3" == "PATCH" ]]; then
  echo "https://example.test/pr/7"
  exit 0
fi

if [[ "$1" == "api" && "$2" == repos/owner/repo/issues/7/comments ]]; then
  echo "[]"
  exit 0
fi

if [[ "$1" == "pr" && "$2" == "create" ]]; then
  echo "https://example.test/pr/7"
  exit 0
fi

if [[ "$1" == "pr" && "$2" == "view" && " $* " == *" --json number "* ]]; then
  echo "7"
  exit 0
fi

if [[ "$1" == "pr" && "$2" == "view" ]]; then
  exit 0
fi

if [[ "$1" == "pr" && "$2" == "edit" ]]; then
  exit 0
fi

echo "Unsupported gh call: $*" >&2
exit 1
EOF

chmod +x "${TMP_DIR}/bin/git" "${TMP_DIR}/bin/gh"

# Every value below would run a command or change the command line if it were
# ever evaluated by a shell. The marker files prove that none of them are.
SOURCE_PAYLOAD="src\$(touch ${TMP_DIR}/pwned-source);\`touch ${TMP_DIR}/pwned-source-bt\`|id"
TARGET_PAYLOAD="tgt\$(touch ${TMP_DIR}/pwned-target);touch ${TMP_DIR}/pwned-target-semi"
TITLE_PAYLOAD="title\$(touch ${TMP_DIR}/pwned-title) && touch ${TMP_DIR}/pwned-title-and"
REVIEWER_PAYLOAD="rev\$(touch ${TMP_DIR}/pwned-reviewer);id"
ASSIGNEE_PAYLOAD="asg\`touch ${TMP_DIR}/pwned-assignee\`"
LABEL_PAYLOAD="lbl\$(touch ${TMP_DIR}/pwned-label)|cat"
MILESTONE_PAYLOAD="ms';touch ${TMP_DIR}/pwned-milestone;'"
PROJECT_PAYLOAD="prj\$(touch ${TMP_DIR}/pwned-project)>${TMP_DIR}/pwned-project-redirect"
BODY_PAYLOAD="body \$(touch ${TMP_DIR}/pwned-body) \`touch ${TMP_DIR}/pwned-body-bt\`"

run_entrypoint() {
  local existing_pr="$1"
  local log_file="$2"

  : > "${TMP_DIR}/gh.args"
  set +e
  PATH="${TMP_DIR}/bin:${PATH}" \
  GH_ARGS_FILE="${TMP_DIR}/gh.args" \
  STUB_EXISTING_PR="${existing_pr}" \
  GITHUB_ACTOR="ci-user" \
  GITHUB_REPOSITORY="owner/repo" \
  GITHUB_WORKSPACE="${TMP_DIR}" \
  GITHUB_OUTPUT="${TMP_DIR}/output.txt" \
  INPUT_GITHUB_TOKEN="token" \
  INPUT_REPOSITORY_PATH="repo" \
  INPUT_SOURCE_BRANCH="${SOURCE_PAYLOAD}" \
  INPUT_TARGET_BRANCH="${TARGET_PAYLOAD}" \
  INPUT_TITLE="${TITLE_PAYLOAD}" \
  INPUT_BODY="${BODY_PAYLOAD}" \
  INPUT_REVIEWER="${REVIEWER_PAYLOAD}" \
  INPUT_ASSIGNEE="${ASSIGNEE_PAYLOAD}" \
  INPUT_LABEL="${LABEL_PAYLOAD}" \
  INPUT_MILESTONE="${MILESTONE_PAYLOAD}" \
  INPUT_PROJECT="${PROJECT_PAYLOAD}" \
  INPUT_DRAFT="true" \
  bash "${SCRIPT_PATH}" >"${log_file}" 2>&1
  local status="$?"
  set -e

  if [[ "${status}" != "0" ]]; then
    echo "Expected successful execution (existing_pr=${existing_pr})" >&2
    cat "${log_file}" >&2
    exit 1
  fi
}

# Create path
run_entrypoint "false" "${TMP_DIR}/create.log"
assert_no_marker
assert_arg "owner:${SOURCE_PAYLOAD}"
assert_arg "${TARGET_PAYLOAD}"
assert_arg "${TITLE_PAYLOAD}"
assert_arg "${REVIEWER_PAYLOAD}"
assert_arg "${ASSIGNEE_PAYLOAD}"
assert_arg "${LABEL_PAYLOAD}"
assert_arg "${MILESTONE_PAYLOAD}"
assert_arg "${PROJECT_PAYLOAD}"
assert_arg "--draft"
grep -Fq -- "${BODY_PAYLOAD}" /tmp/template

# Update path
run_entrypoint "true" "${TMP_DIR}/update.log"
assert_no_marker
assert_arg "repos/owner/repo/pulls/7"
assert_arg "body=@/tmp/template"
assert_arg "${PROJECT_PAYLOAD}"
grep -Fq -- "${BODY_PAYLOAD}" /tmp/template

echo "Shell metacharacter tests passed."
