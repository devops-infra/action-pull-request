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
  if [[ "${last_arg}" == "refs/remotes/origin/develop" || "${last_arg}" == "refs/remotes/origin/main" ]]; then
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
  if [[ "${last_arg}" == "origin/main" ]]; then
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

if [[ "$#" -ge 1 && "$1" == "api" ]]; then
  if [[ "${cmd}" == *"repos/owner/repo/pulls?state=open&base=main"* ]]; then
    printf '%s\n' '[{"number":88,"head":{"ref":"other-branch","repo":{"full_name":"owner/repo"}}},{"number":123,"head":{"ref":"develop","repo":{"full_name":"owner/repo"}}},{"number":321,"head":{"ref":"develop","repo":{"full_name":"fork/repo"}}}]'
    exit 0
  fi
  if [[ "${cmd}" == *"repos/owner/repo/pulls/123"* && "${cmd}" == *"--method GET"* ]]; then
    echo "OLD BODY"
    exit 0
  fi
  if [[ "${cmd}" == *"repos/owner/repo/pulls/123"* && "${cmd}" == *"--method PATCH"* ]]; then
    echo "https://example.test/pr/123"
    exit 0
  fi
  if [[ "${cmd}" == *"repos/owner/repo/issues/123/comments"* ]]; then
    echo "[]"
    exit 0
  fi
fi

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "create" ]]; then
  echo "gh pr create should not be called when PR already exists" >&2
  exit 1
fi

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "view" ]]; then
  if [[ "${cmd}" == *"--json projectItems,projectCards"* ]]; then
    exit 0
  fi
fi

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "edit" ]]; then
  if [[ "${cmd}" != *"--repo owner/repo"* || "${cmd}" != *"--add-project Roadmap"* || "${cmd}" != *"123"* ]]; then
    echo "Missing project add call in update mode" >&2
    exit 1
  fi
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
INPUT_TARGET_BRANCH="main" \
INPUT_TITLE="" \
INPUT_TEMPLATE="${TMP_DIR}/template.md" \
INPUT_BODY="" \
INPUT_REVIEWER="" \
INPUT_ASSIGNEE="" \
INPUT_LABEL="" \
INPUT_MILESTONE="" \
INPUT_PROJECT="Roadmap" \
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

if [[ "${STATUS}" != "0" ]]; then
  echo "Expected successful execution in update mode" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

assert_contains "${LOG_FILE}" "Updating pull request"
assert_contains "${LOG_FILE}" "Adding pull request #123 to project 'Roadmap'"
assert_contains "${TMP_DIR}/output.txt" "url=https://example.test/pr/123"
assert_contains "${TMP_DIR}/output.txt" "pr_number=123"

echo "Existing PR lookup test passed."
