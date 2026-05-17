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

cat > "${TMP_DIR}/bin/git" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ge 2 && "$1" == "config" && "$2" == "--global" ]]; then
  exit 0
fi

if [[ "$#" -ge 2 && "$1" == "remote" && "$2" == "set-url" ]]; then
  exit 0
fi

if [[ "$#" -ge 1 && "$1" == "fetch" ]]; then
  exit 0
fi

if [[ "$#" -ge 2 && "$1" == "show-ref" ]]; then
  if [[ "${@: -1}" == "refs/remotes/origin/develop" || "${@: -1}" == "refs/remotes/origin/release/MAPL-v3" ]]; then
    exit 0
  fi
  exit 1
fi

if [[ "$#" -ge 2 && "$1" == "rev-parse" ]]; then
  if [[ "${@: -1}" == "origin/develop" ]]; then
    echo "bbb222"
    exit 0
  fi
  if [[ "${@: -1}" == "origin/release/MAPL-v3" ]]; then
    echo "aaa111"
    exit 0
  fi
fi

if [[ "$#" -ge 2 && "$1" == "diff" && "$2" == "--quiet" ]]; then
  exit 1
fi

if [[ "$#" -ge 1 && "$1" == "diff" ]]; then
  echo "M README.md"
  exit 0
fi

if [[ "$#" -ge 1 && "$1" == "log" ]]; then
  echo "stub log"
  exit 0
fi

if [[ "$#" -ge 2 && "$1" == "symbolic-ref" ]]; then
  echo "develop"
  exit 0
fi

echo "Unsupported git call: $*" >&2
exit 1
EOF

cat > "${TMP_DIR}/bin/hub" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ge 2 && "$1" == "pr" && "$2" == "list" ]]; then
  echo "123"
  exit 0
fi

if [[ "$#" -ge 3 && "$1" == "api" && "$2" == "--method" && "$3" == "GET" ]]; then
  echo '{"body":"OLD BODY WITHOUT MARKERS"}'
  exit 0
fi

if [[ "$#" -ge 3 && "$1" == "api" && "$2" == "--method" && "$3" == "PATCH" ]]; then
  echo '{"html_url":"https://example.test/pr/123"}'
  exit 0
fi

echo "Unsupported hub call: $*" >&2
exit 1
EOF

cat > "${TMP_DIR}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ge 2 && "$1" == "api" ]]; then
  if [[ "$2" == "repos/owner/repo/issues/123/comments" ]]; then
    echo "[]"
    exit 0
  fi
  if [[ "$2" == "repos/owner/repo/issues/comments/"* ]]; then
    exit 0
  fi
fi

echo "Unsupported gh call: $*" >&2
exit 1
EOF

cat > "${TMP_DIR}/template.md" <<'EOF'
## Template
<!-- Diff files - START -->
<!-- Diff files - END -->
EOF

chmod +x "${TMP_DIR}/bin/git" "${TMP_DIR}/bin/hub" "${TMP_DIR}/bin/gh"

LOG_FILE="${TMP_DIR}/run.log"
set +e
PATH="${TMP_DIR}/bin:${PATH}" \
GITHUB_ACTOR="ci-user" \
GITHUB_TOKEN="token" \
GITHUB_REPOSITORY="owner/repo" \
GITHUB_WORKSPACE="${TMP_DIR}" \
GITHUB_OUTPUT="${TMP_DIR}/output.txt" \
INPUT_GITHUB_TOKEN="token" \
INPUT_SOURCE_BRANCH="develop" \
INPUT_TARGET_BRANCH="release/MAPL-v3" \
INPUT_TITLE="" \
INPUT_TEMPLATE="${TMP_DIR}/template.md" \
INPUT_BODY="" \
INPUT_REVIEWER="" \
INPUT_ASSIGNEE="" \
INPUT_LABEL="" \
INPUT_MILESTONE="" \
INPUT_DRAFT="false" \
INPUT_GET_DIFF="true" \
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

assert_contains "${LOG_FILE}" "Template source: input template file (update mode)"
assert_contains "${LOG_FILE}" "Detected diff markers: summary=false commits=false files=true"

echo "Template source selection test passed."
