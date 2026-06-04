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

mkdir -p "${TMP_DIR}/bin"
mkdir -p "${TMP_DIR}/repo"

cat > "${TMP_DIR}/bin/git" <<'EOF'
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

cat > "${TMP_DIR}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

cmd="$*"

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "list" ]]; then
  exit 0
fi

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "create" ]]; then
  if [[ "${cmd}" != *"--repo owner/repo"* ]]; then
    echo "Missing --repo" >&2
    exit 1
  fi
  if [[ "${cmd}" != *"--base release/MAPL-v3"* ]]; then
    echo "Missing --base" >&2
    exit 1
  fi
  if [[ "${cmd}" != *"--head owner:develop"* ]]; then
    echo "Missing --head" >&2
    exit 1
  fi
  if [[ "${cmd}" != *"--title My PR title"* ]]; then
    echo "Missing --title" >&2
    exit 1
  fi
  if [[ "${cmd}" != *"--body-file /tmp/template"* ]]; then
    echo "Missing --body-file" >&2
    exit 1
  fi
  if [[ "${cmd}" != *"--reviewer alice"* || "${cmd}" != *"--reviewer bob"* ]]; then
    echo "Missing reviewers" >&2
    exit 1
  fi
  if [[ "${cmd}" != *"--assignee assignee1"* || "${cmd}" != *"--assignee assignee2"* ]]; then
    echo "Missing assignees" >&2
    exit 1
  fi
  if [[ "${cmd}" != *"--label bug"* || "${cmd}" != *"--label chore"* ]]; then
    echo "Missing labels" >&2
    exit 1
  fi
  if [[ "${cmd}" != *"--milestone Milestone-1"* ]]; then
    echo "Missing milestone" >&2
    exit 1
  fi
  if [[ "${cmd}" != *"--draft"* ]]; then
    echo "Missing draft flag" >&2
    exit 1
  fi

  echo "https://example.test/pr/456"
  exit 0
fi

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "view" ]]; then
  echo "456"
  exit 0
fi

echo "Unsupported gh call: $*" >&2
exit 1
EOF

cat > "${TMP_DIR}/template.md" <<'EOF'
## Template body from file
EOF

chmod +x "${TMP_DIR}/bin/git" "${TMP_DIR}/bin/gh"

LOG_FILE="${TMP_DIR}/run.log"
set +e
PATH="${TMP_DIR}/bin:${PATH}" \
GITHUB_ACTOR="ci-user" \
GITHUB_TOKEN="token" \
GITHUB_REPOSITORY="owner/repo" \
GITHUB_WORKSPACE="${TMP_DIR}" \
GITHUB_OUTPUT="${TMP_DIR}/output.txt" \
INPUT_GITHUB_TOKEN="token" \
INPUT_REPOSITORY_PATH="repo" \
INPUT_SOURCE_BRANCH="develop" \
INPUT_TARGET_BRANCH="release/MAPL-v3" \
INPUT_TITLE="My PR title" \
INPUT_TEMPLATE="${TMP_DIR}/template.md" \
INPUT_BODY="" \
INPUT_REVIEWER="alice,bob" \
INPUT_ASSIGNEE="assignee1,assignee2" \
INPUT_LABEL="bug,chore" \
INPUT_MILESTONE="Milestone-1" \
INPUT_DRAFT="true" \
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

if [[ "${STATUS}" != "0" ]]; then
  echo "Expected successful execution in create mode" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

assert_contains "${LOG_FILE}" "Creating pull request"
assert_contains "${LOG_FILE}" "Running: gh pr create --repo owner/repo --base release/MAPL-v3 --head owner:develop"
assert_contains "${TMP_DIR}/output.txt" "url=https://example.test/pr/456"
assert_contains "${TMP_DIR}/output.txt" "pr_number=456"

echo "GH create flow test passed."
