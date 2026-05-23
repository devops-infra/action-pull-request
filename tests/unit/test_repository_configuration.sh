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

WORKSPACE_DIR="${TMP_DIR}/workspace"
REPOSITORY_SUBPATH="repo"
REPO_DIR="${WORKSPACE_DIR}/${REPOSITORY_SUBPATH}"
EXPECTED_REPO_DIR="$(python3 - "${REPO_DIR}" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve(strict=False))
PY
)"
mkdir -p "${REPO_DIR}" "${TMP_DIR}/home" "${TMP_DIR}/bin"

git init --initial-branch=main "${REPO_DIR}" >/dev/null
pushd "${REPO_DIR}" >/dev/null
git config user.name "tester"
git config user.email "tester@example.com"
printf 'x\n' > README.md
git add README.md
git commit -m "init" >/dev/null
git branch develop
git update-ref refs/remotes/origin/main refs/heads/main
git update-ref refs/remotes/origin/develop refs/heads/develop
git remote add origin .
popd >/dev/null

cat > "${TMP_DIR}/bin/git" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REAL_GIT="${REAL_GIT:-/usr/bin/git}"
CALLS_LOG="${GIT_WRAPPER_CALLS_LOG:?}"
ENV_LOG="${GIT_WRAPPER_ENV_LOG:?}"

printf '%s\n' "$*" >> "${CALLS_LOG}"
printf '%s\n' "${GIT_CONFIG_GLOBAL:-}" >> "${ENV_LOG}"

if [[ "$#" -ge 2 && "$1" == "remote" && "$2" == "set-url" ]]; then
  exit 0
fi

if [[ "$#" -ge 1 && "$1" == "fetch" ]]; then
  exec "${REAL_GIT}" fetch . '+refs/heads/*:refs/heads/*' --update-head-ok
fi

exec "${REAL_GIT}" "$@"
EOF
chmod +x "${TMP_DIR}/bin/git"

LOG_FILE="${TMP_DIR}/run.log"
CALLS_LOG="${TMP_DIR}/git-calls.log"
ENV_LOG="${TMP_DIR}/git-env.log"

set +e
(
  cd "${REPO_DIR}"
  PATH="${TMP_DIR}/bin:${PATH}" \
  REAL_GIT="$(command -v git)" \
  GIT_WRAPPER_CALLS_LOG="${CALLS_LOG}" \
  GIT_WRAPPER_ENV_LOG="${ENV_LOG}" \
  HOME="${TMP_DIR}/home" \
  GITHUB_ACTOR="ci-user" \
  GITHUB_TOKEN="token" \
  GITHUB_REPOSITORY="owner/workflow-repo" \
  GITHUB_WORKSPACE="${WORKSPACE_DIR}" \
  GITHUB_OUTPUT="${TMP_DIR}/output.txt" \
  INPUT_GITHUB_TOKEN="token" \
  INPUT_REPOSITORY="octo/demo" \
  INPUT_REPOSITORY_PATH="${REPOSITORY_SUBPATH}" \
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
)
STATUS="$?"
set -e

if [[ "${STATUS}" != "0" ]]; then
  echo "Expected successful execution with repository/repository_path inputs" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

assert_contains "${LOG_FILE}" "Repository: octo/demo"
assert_contains "${LOG_FILE}" "Repository path: ${EXPECTED_REPO_DIR}"
assert_contains "${CALLS_LOG}" "remote set-url origin https://ci-user:token@github.com/octo/demo"

if [[ -f "${TMP_DIR}/home/.gitconfig" ]]; then
  echo "Expected HOME git config to stay untouched" >&2
  cat "${TMP_DIR}/home/.gitconfig" >&2
  exit 1
fi

if ! grep -Eq '^/tmp/action-pull-request-git-config-' "${ENV_LOG}"; then
  echo "Expected isolated GIT_CONFIG_GLOBAL path in git wrapper env log" >&2
  cat "${ENV_LOG}" >&2
  exit 1
fi

echo "Repository configuration test passed."
