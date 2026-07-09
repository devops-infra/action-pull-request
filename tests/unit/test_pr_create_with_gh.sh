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

if [[ "$#" -ge 3 && "$1" == "api" && "$2" == "--method" && "$3" == "GET" && "$4" == "repos/owner/repo/pulls?state=open&base=release/MAPL-v3" ]]; then
  echo "[]"
  exit 0
fi

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "create" ]]; then
  expect_repo="false"
  expect_base="false"
  expect_head="false"
  expect_title="false"
  expect_body_file="false"
  expect_milestone="false"
  expect_project="false"
  expect_draft="false"
  reviewer_alice="false"
  reviewer_bob="false"
  assignee_one="false"
  assignee_two="false"
  label_bug="false"
  label_chore="false"
  previous=""

  for arg in "$@"; do
    case "${previous}:${arg}" in
      --repo:owner/repo) expect_repo="true" ;;
      --base:release/MAPL-v3) expect_base="true" ;;
      --head:owner:develop) expect_head="true" ;;
      --title:"My PR title") expect_title="true" ;;
      --body-file:/tmp/template) expect_body_file="true" ;;
      --reviewer:alice) reviewer_alice="true" ;;
      --reviewer:bob) reviewer_bob="true" ;;
      --assignee:assignee1) assignee_one="true" ;;
      --assignee:assignee2) assignee_two="true" ;;
      --label:bug) label_bug="true" ;;
      --label:chore) label_chore="true" ;;
      --milestone:Milestone-1) expect_milestone="true" ;;
      --project:Roadmap) expect_project="true" ;;
    esac
    if [[ "${arg}" == "--draft" ]]; then
      expect_draft="true"
    fi
    previous="${arg}"
  done

  if [[ "${expect_repo}" != "true" || "${expect_base}" != "true" || "${expect_head}" != "true" || "${expect_title}" != "true" || "${expect_body_file}" != "true" ]]; then
    echo "Missing required PR create arguments" >&2
    exit 1
  fi
  if [[ "${reviewer_alice}" != "true" || "${reviewer_bob}" != "true" ]]; then
    echo "Missing reviewers" >&2
    exit 1
  fi
  if [[ "${assignee_one}" != "true" || "${assignee_two}" != "true" ]]; then
    echo "Missing assignees" >&2
    exit 1
  fi
  if [[ "${label_bug}" != "true" || "${label_chore}" != "true" ]]; then
    echo "Missing labels" >&2
    exit 1
  fi
  if [[ "${expect_milestone}" != "true" ]]; then
    echo "Missing milestone" >&2
    exit 1
  fi
  if [[ "${expect_project}" != "true" ]]; then
    echo "Missing project" >&2
    exit 1
  fi
  if [[ "${expect_draft}" != "true" ]]; then
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
INPUT_PROJECT="Roadmap" \
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
