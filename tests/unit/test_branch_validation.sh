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

git init --initial-branch=main "${TMP_DIR}/repo" >/dev/null

mkdir -p "${TMP_DIR}/bin"
cat > "${TMP_DIR}/bin/git" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REAL_GIT="${REAL_GIT:-/usr/bin/git}"

if [[ "$#" -ge 2 && "$1" == "remote" && "$2" == "set-url" ]]; then
  exit 0
fi

if [[ "$#" -ge 1 && "$1" == "fetch" ]]; then
  exec "${REAL_GIT}" fetch . '+refs/heads/*:refs/heads/*' --update-head-ok
fi

exec "${REAL_GIT}" "$@"
EOF
chmod +x "${TMP_DIR}/bin/git"

pushd "${TMP_DIR}/repo" >/dev/null
git config user.name "tester"
git config user.email "tester@example.com"
printf 'x\n' > README.md
git add README.md
git commit -m "init" >/dev/null
git branch develop
git update-ref refs/remotes/origin/develop refs/heads/develop
git remote add origin .
popd >/dev/null

LOG_FILE="${TMP_DIR}/run.log"
set +e
(
  cd "${TMP_DIR}/repo"
  PATH="${TMP_DIR}/bin:${PATH}" \
  REAL_GIT="$(command -v git)" \
  GITHUB_ACTOR="ci-user" \
  GITHUB_TOKEN="token" \
  GITHUB_REPOSITORY="owner/repo" \
  GITHUB_WORKSPACE="${TMP_DIR}/repo" \
  GITHUB_OUTPUT="${TMP_DIR}/output.txt" \
  INPUT_GITHUB_TOKEN="token" \
  INPUT_SOURCE_BRANCH="develop" \
  INPUT_TARGET_BRANCH="release/MAPL-v3" \
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
)
STATUS="$?"
set -e

if [[ "${STATUS}" == "0" ]]; then
  echo "Expected non-zero exit code when target branch is missing" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

assert_contains "${LOG_FILE}" "[ERROR] Missing branch reference: release/MAPL-v3"

echo "Branch validation test passed."
