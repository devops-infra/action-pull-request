#!/usr/bin/env bash

set -Eeuo pipefail

# Return code
RET_CODE=0
GIT_LOG=""
GIT_SUMMARY=""
GIT_DIFF=""
SOURCE_COMPARE_REF=""
TARGET_COMPARE_REF=""
RESOLVED_BRANCH_REF=""
MAX_BODY_BYTES=""
MAX_DIFF_LINES=""
MAX_COMMENT_BODY_BYTES=""
OVERFLOW_MAIN_FILE="/tmp/template-overflow-main.md"
OVERFLOW_CHUNK_PREFIX="/tmp/template-overflow-chunk"
CHUNK_COUNT=0
MANAGED_COMMENT_START="<!-- action-pull-request:managed-diff-chunk:start -->"
MANAGED_COMMENT_END="<!-- action-pull-request:managed-diff-chunk:end -->"
TARGET_REPOSITORY=""
TARGET_OWNER=""
REPOSITORY_PATH=""
WORKSPACE_DIR=""
REPO_DIR=""

REPLACE_TEMPLATE_SCRIPT="/scripts/replace-template-diff.sh"
if [[ ! -x "${REPLACE_TEMPLATE_SCRIPT}" ]]; then
  REPLACE_TEMPLATE_SCRIPT="$(dirname "$0")/scripts/replace-template-diff.sh"
fi

SPLIT_CONTENT_SCRIPT="/scripts/split_content_bytes.py"
if [[ ! -f "${SPLIT_CONTENT_SCRIPT}" ]]; then
  SPLIT_CONTENT_SCRIPT="$(dirname "$0")/scripts/split_content_bytes.py"
fi

get_git_log() {
  if [[ -z "${GIT_LOG}" ]]; then
    echo -e "\nListing new commits in the source branch..."
    git log --graph --pretty=format:'%Cred%h%Creset - %Cblue%an%Creset - %Cgreen%cd%Creset %n%s %b' --abbrev-commit --date=format:'%Y-%m-%d %H:%M:%S' "${TARGET_COMPARE_REF}...${SOURCE_COMPARE_REF}"
    GIT_LOG=$(git log --graph --pretty=format:'%Cred%h%Creset - %Cblue%an%Creset - %Cgreen%cd%Creset %n%s%n%b' --abbrev-commit --date=format:'%Y-%m-%d %H:%M:%S' --no-color "${TARGET_COMPARE_REF}...${SOURCE_COMPARE_REF}")
  fi
}

get_git_summary() {
  if [[ -z "${GIT_SUMMARY}" ]]; then
    echo -e "\n\nListing commits subjects in the source branch..."
    git log --reverse --pretty=format:'%s' --abbrev-commit "${TARGET_COMPARE_REF}...${SOURCE_COMPARE_REF}"
    GIT_SUMMARY=$(git log --reverse --pretty=format:'%s' --abbrev-commit "${TARGET_COMPARE_REF}...${SOURCE_COMPARE_REF}")
  fi
}

get_git_diff() {
  if [[ -z "${GIT_DIFF}" ]]; then
    echo -e "\n\nListing files modified in the source branch..."
    git diff --compact-summary "${TARGET_COMPARE_REF}...${SOURCE_COMPARE_REF}"
    GIT_DIFF=$(git diff --compact-summary --no-color "${TARGET_COMPARE_REF}...${SOURCE_COMPARE_REF}")
  fi
}

resolve_branch_ref() {
  local branch_name="$1"
  local remote_ref="refs/remotes/origin/${branch_name}"
  local head_ref="refs/heads/${branch_name}"

  if git show-ref --verify --quiet "${remote_ref}"; then
    RESOLVED_BRANCH_REF="origin/${branch_name}"
    return 0
  fi

  if git show-ref --verify --quiet "${head_ref}"; then
    RESOLVED_BRANCH_REF="${branch_name}"
    return 0
  fi

  echo -e "\n[ERROR] Missing branch reference: ${branch_name}" >&2
  return 1
}

validate_number_input() {
  local value="$1"
  local input_name="$2"

  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    echo -e "\n[ERROR] Input '${input_name}' must be a non-negative integer. Got: ${value}" >&2
    exit 1
  fi
}

apply_line_cap() {
  local file_path="$1"
  local max_lines="$2"
  local section_name="$3"

  if [[ "${max_lines}" == "0" ]]; then
    return 0
  fi

  python3 - "$file_path" "$max_lines" "$section_name" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
limit = int(sys.argv[2])
section = sys.argv[3]
content = path.read_text(encoding="utf-8")
lines = content.splitlines()
if len(lines) <= limit:
    raise SystemExit(0)
trimmed = lines[:limit]
removed = len(lines) - len(trimmed)
if limit == 1:
    trimmed = [f"... truncated {removed} lines from {section} because max_diff_lines={limit} ..."]
else:
    trimmed = lines[: limit - 1]
    removed = len(lines) - len(trimmed)
    trimmed.append(f"... truncated {removed} lines from {section} because max_diff_lines={limit} ...")
path.write_text("\n".join(trimmed) + "\n", encoding="utf-8")
PY
}

write_chunk_comment_file() {
  local chunk_body_file="$1"
  local index="$2"
  local total="$3"
  local output_file="$4"

  {
    printf '%s\n' "${MANAGED_COMMENT_START}"
    printf '<!-- action-pull-request:managed-diff-chunk:index=%s total=%s -->\n' "${index}" "${total}"
    cat "${chunk_body_file}"
    printf '\n%s\n' "${MANAGED_COMMENT_END}"
  } > "${output_file}"
}

split_template_by_bytes() {
  local input_file="$1"
  local main_output_file="$2"
  local chunk_prefix="$3"
  local max_main_bytes="$4"
  local max_comment_bytes="$5"

  python3 "${SPLIT_CONTENT_SCRIPT}" "${input_file}" "${main_output_file}" "${chunk_prefix}" "${max_main_bytes}" "${max_comment_bytes}"
}

resolve_path() {
  local input_path="$1"
  python3 - "$input_path" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).resolve(strict=False))
PY
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

append_csv_arg() {
  local flag="$1"
  local csv_value="$2"
  local -n args_ref="$3"
  local raw_value trimmed_value
  local -a parsed_values

  if [[ -z "${csv_value}" ]]; then
    return 0
  fi

  IFS=',' read -r -a parsed_values <<< "${csv_value}"
  for raw_value in "${parsed_values[@]}"; do
    trimmed_value="$(trim_whitespace "${raw_value}")"
    if [[ -n "${trimmed_value}" ]]; then
      args_ref+=("${flag}" "${trimmed_value}")
    fi
  done
}

get_managed_comment_ids() {
  local pr_number="$1"
  local output_file="$2"

  gh api "repos/${TARGET_REPOSITORY}/issues/${pr_number}/comments" --paginate | jq -r \
    --arg start "${MANAGED_COMMENT_START}" \
    --arg end "${MANAGED_COMMENT_END}" \
    'if type == "array" then .[] else . end
     | select((.body // "" | contains($start)) and (.body // "" | contains($end)))
     | .id' | sort -n > "${output_file}"
}

reconcile_managed_comments() {
  local pr_number="$1"
  local chunk_count="$2"

  local ids_file="/tmp/managed-comment-ids.txt"
  get_managed_comment_ids "${pr_number}" "${ids_file}"

  local -a existing_ids=()
  while IFS= read -r line; do
    if [[ -n "${line}" ]]; then
      existing_ids+=("${line}")
    fi
  done < "${ids_file}"

  local idx
  for ((idx=1; idx<=chunk_count; idx++)); do
    local raw_chunk_file="${OVERFLOW_CHUNK_PREFIX}-${idx}.txt"
    local comment_file="${OVERFLOW_CHUNK_PREFIX}-${idx}.comment.md"
    write_chunk_comment_file "${raw_chunk_file}" "${idx}" "${chunk_count}" "${comment_file}"

    if (( idx <= ${#existing_ids[@]} )); then
      local comment_id="${existing_ids[$((idx-1))]}"
      gh api --method PATCH "repos/${TARGET_REPOSITORY}/issues/comments/${comment_id}" --field "body=@${comment_file}" >/dev/null
    else
      gh api --method POST "repos/${TARGET_REPOSITORY}/issues/${pr_number}/comments" --field "body=@${comment_file}" >/dev/null
    fi
  done

  if (( ${#existing_ids[@]} > chunk_count )); then
    for ((idx=chunk_count+1; idx<=${#existing_ids[@]}; idx++)); do
      local stale_id="${existing_ids[$((idx-1))]}"
      gh api --method DELETE "repos/${TARGET_REPOSITORY}/issues/comments/${stale_id}" >/dev/null
    done
  fi
}

apply_body_limits() {
  local template_file="$1"
  local max_body_bytes="$2"
  local max_comment_bytes="$3"

  local template_size
  template_size="$(wc -c < "${template_file}" | tr -d '[:space:]')"
  if (( template_size <= max_body_bytes )); then
    CHUNK_COUNT=0
    cp "${template_file}" "${OVERFLOW_MAIN_FILE}"
    return 0
  fi

  echo -e "\n[INFO] PR body exceeds max_body_bytes=${max_body_bytes}. Splitting overflow into managed comments."

  local with_note_file="/tmp/template-with-note.md"
  {
    printf '_Note: Additional diff output is included in managed comments because body size exceeded max_body_bytes=%s._\n' "${max_body_bytes}"
    printf '\n---\n\n'
    cat "${template_file}"
  } > "${with_note_file}"

  CHUNK_COUNT="$(split_template_by_bytes "${with_note_file}" "${OVERFLOW_MAIN_FILE}" "${OVERFLOW_CHUNK_PREFIX}" "${max_body_bytes}" "${max_comment_bytes}")"
}

echo "Inputs:"
echo "  repository: ${INPUT_REPOSITORY:-}"
echo "  repository_path: ${INPUT_REPOSITORY_PATH:-.}"
echo "  source_branch: ${INPUT_SOURCE_BRANCH}"
echo "  target_branch: ${INPUT_TARGET_BRANCH}"
echo "  title: ${INPUT_TITLE}"
echo "  template: ${INPUT_TEMPLATE}"
echo "  body: ${INPUT_BODY}"
echo "  reviewer: ${INPUT_REVIEWER}"
echo "  assignee: ${INPUT_ASSIGNEE}"
echo "  label: ${INPUT_LABEL}"
echo "  milestone: ${INPUT_MILESTONE}"
echo "  draft: ${INPUT_DRAFT}"
echo "  get_diff: ${INPUT_GET_DIFF}"
echo "  old_string: ${INPUT_OLD_STRING}"
echo "  new_string: ${INPUT_NEW_STRING}"
echo "  ignore_users: ${INPUT_IGNORE_USERS}"
echo "  allow_no_diff: ${INPUT_ALLOW_NO_DIFF}"
echo "  max_body_bytes: ${INPUT_MAX_BODY_BYTES}"
echo "  max_diff_lines: ${INPUT_MAX_DIFF_LINES}"

MAX_BODY_BYTES="${INPUT_MAX_BODY_BYTES:-65000}"
MAX_DIFF_LINES="${INPUT_MAX_DIFF_LINES:-0}"
validate_number_input "${MAX_BODY_BYTES}" "max_body_bytes"
validate_number_input "${MAX_DIFF_LINES}" "max_diff_lines"

if (( MAX_BODY_BYTES < 2048 )); then
  echo -e "\n[ERROR] Input 'max_body_bytes' must be at least 2048. Got: ${MAX_BODY_BYTES}" >&2
  exit 1
fi

MAX_COMMENT_BODY_BYTES=$((MAX_BODY_BYTES - 512))
if (( MAX_COMMENT_BODY_BYTES < 1024 )); then
  MAX_COMMENT_BODY_BYTES=1024
fi

# Skip whole script to not cause errors
IFS=',' read -r -a IGNORE_USERS <<< "${INPUT_IGNORE_USERS}"
for USER in "${IGNORE_USERS[@]}"
do
  if [[ "${GITHUB_ACTOR}" == "${USER}" ]]; then
    MESSAGE="User ${GITHUB_ACTOR} is ignored. Skipping."
    echo -e "\n[INFO] ${MESSAGE}"
    exit 0
  fi
done

# Require github_token
if [[ -z "${INPUT_GITHUB_TOKEN}" ]]; then
  # shellcheck disable=SC2016
  MESSAGE='Missing input "github_token: ${{ secrets.GITHUB_TOKEN }}".'
  echo -e "[ERROR] ${MESSAGE}"
  exit 1
fi

TARGET_REPOSITORY="${INPUT_REPOSITORY:-${GITHUB_REPOSITORY}}"
if [[ -z "${TARGET_REPOSITORY}" ]]; then
  echo -e "\n[ERROR] Unable to resolve repository. Set input 'repository' or ensure GITHUB_REPOSITORY is available." >&2
  exit 1
fi
if [[ ! "${TARGET_REPOSITORY}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,38})/[A-Za-z0-9._-]+$ ]]; then
  echo -e "\n[ERROR] Input 'repository' must use owner/name format. Got: ${TARGET_REPOSITORY}" >&2
  exit 1
fi
TARGET_OWNER="${TARGET_REPOSITORY%%/*}"

REPOSITORY_PATH="${INPUT_REPOSITORY_PATH:-.}"
if [[ -z "${REPOSITORY_PATH}" ]]; then
  REPOSITORY_PATH="."
fi
if [[ "${REPOSITORY_PATH}" == /* ]]; then
  echo -e "\n[ERROR] Input 'repository_path' must be a relative path under GITHUB_WORKSPACE." >&2
  exit 1
fi

WORKSPACE_DIR="$(resolve_path "${GITHUB_WORKSPACE}")"
REPO_DIR="$(resolve_path "${GITHUB_WORKSPACE}/${REPOSITORY_PATH}")"
if [[ "${REPO_DIR}" != "${WORKSPACE_DIR}" && "${REPO_DIR}" != "${WORKSPACE_DIR}"/* ]]; then
  echo -e "\n[ERROR] Input 'repository_path' resolves outside GITHUB_WORKSPACE." >&2
  exit 1
fi
if [[ ! -d "${REPO_DIR}" ]]; then
  echo -e "\n[ERROR] Repository path does not exist: ${REPO_DIR}" >&2
  exit 1
fi

# Keep all global git config isolated to a temporary file
export GIT_CONFIG_GLOBAL
GIT_CONFIG_GLOBAL="$(mktemp /tmp/action-pull-request-git-config-XXXXXX)"
trap 'rm -f "${GIT_CONFIG_GLOBAL}"' EXIT

# Prevents issues with: fatal: unsafe repository ('/github/workspace' is owned by someone else)
git config --global --add safe.directory "${WORKSPACE_DIR}"
git config --global --add safe.directory /github/workspace
git config --global --add safe.directory "${REPO_DIR}"

if ! git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo -e "\n[ERROR] Path is not a git repository: ${REPO_DIR}" >&2
  exit 1
fi

echo -e "\nSetting GitHub credentials..."
git -C "${REPO_DIR}" remote set-url origin "https://${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/${TARGET_REPOSITORY}"
git -C "${REPO_DIR}" config user.name "${GITHUB_ACTOR}"
git -C "${REPO_DIR}" config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
echo "Repository: ${TARGET_REPOSITORY}"
echo "Repository path: ${REPO_DIR}"

cd "${REPO_DIR}"

echo -e "\nSetting branches..."
SOURCE_BRANCH="${INPUT_SOURCE_BRANCH:-$(git symbolic-ref --short -q HEAD)}"
TARGET_BRANCH="${INPUT_TARGET_BRANCH:-master}"
echo "Source branch: ${SOURCE_BRANCH}"
echo "Target branch: ${TARGET_BRANCH}"

echo -e "\nUpdating all branches..."
git fetch origin '+refs/heads/*:refs/heads/*' --update-head-ok

echo -e "\nValidating branches..."
if ! resolve_branch_ref "${SOURCE_BRANCH}"; then
  exit 1
fi
SOURCE_COMPARE_REF="${RESOLVED_BRANCH_REF}"

if ! resolve_branch_ref "${TARGET_BRANCH}"; then
  exit 1
fi
TARGET_COMPARE_REF="${RESOLVED_BRANCH_REF}"

echo -e "\nComparing branches by revisions..."
if [[ $(git rev-parse --verify "${SOURCE_COMPARE_REF}") == $(git rev-parse --verify "${TARGET_COMPARE_REF}") ]]; then
  echo -e "\n[INFO] Both branches are the same. No action needed."
  exit 0
fi

echo -e "\nComparing branches by diff..."
if git diff --quiet "${TARGET_COMPARE_REF}...${SOURCE_COMPARE_REF}"; then
  if [[ "${INPUT_ALLOW_NO_DIFF}" == "true" ]]; then
    echo -e "\n[INFO] Both branches are the same. Continuing."
  else
    echo -e "\n[INFO] Both branches are the same. No action needed."
    exit 0
  fi
else
  DIFF_STATUS="$?"
  if [[ "${DIFF_STATUS}" != "1" ]]; then
    echo -e "\n[ERROR] Failed to compare branches by diff (git exit code: ${DIFF_STATUS})."
    exit 1
  fi
fi

echo -e "\nSetting template..."
PR_NUMBER="$(gh pr list --repo "${TARGET_REPOSITORY}" --state open --base "${TARGET_BRANCH}" --head "${TARGET_OWNER}:${SOURCE_BRANCH}" --json number --jq '.[0].number // empty')"
if [[ -z "${PR_NUMBER}" ]]; then
  if [[ -n "${INPUT_TEMPLATE}" ]]; then
    echo "Template source: input template file"
    TEMPLATE=$(cat "${INPUT_TEMPLATE}")
  elif [[ -n "${INPUT_BODY}" ]]; then
    echo "Template source: input body"
    TEMPLATE="${INPUT_BODY}"
  else
    echo "Template source: generated git log"
    get_git_log
    TEMPLATE="${GIT_LOG}"
  fi
else
  if [[ -n "${INPUT_TEMPLATE}" ]]; then
    echo "Template source: input template file (update mode)"
    TEMPLATE=$(cat "${INPUT_TEMPLATE}")
  elif [[ -n "${INPUT_BODY}" ]]; then
    echo "Template source: input body (update mode)"
    TEMPLATE="${INPUT_BODY}"
  else
    echo "Template source: existing pull request body"
    TEMPLATE="$(gh api --method GET "repos/${TARGET_REPOSITORY}/pulls/${PR_NUMBER}" --jq '.body // ""')"
  fi
fi

if [[ -n "${INPUT_OLD_STRING}" ]]; then
  echo -e "\nReplacing old_string with new_string..."
  OLD_STRING=${INPUT_OLD_STRING/\!/\\!}
  if [[ -n "${INPUT_NEW_STRING}" ]]; then
    TEMPLATE=${TEMPLATE/${OLD_STRING}/${INPUT_NEW_STRING}}
  else
    get_git_summary
    TEMPLATE=${TEMPLATE/${OLD_STRING}/${GIT_SUMMARY}}
  fi
fi

if [[ "${INPUT_GET_DIFF}" ==  "true" ]]; then
  echo -e "\nReplacing predefined fields with git information..."
  REPLACE_SUMMARY="false"
  REPLACE_COMMITS="false"
  REPLACE_FILES="false"

  if [[ "${TEMPLATE}" == *"<!-- Diff summary - START -->"* && "${TEMPLATE}" == *"<!-- Diff summary - END -->"* ]]; then
    REPLACE_SUMMARY="true"
  fi
  if [[ "${TEMPLATE}" == *"<!-- Diff commits -->"* || ( "${TEMPLATE}" == *"<!-- Diff commits - START -->"* && "${TEMPLATE}" == *"<!-- Diff commits - END -->"* ) ]]; then
    REPLACE_COMMITS="true"
  fi
  if [[ "${TEMPLATE}" == *"<!-- Diff files -->"* || ( "${TEMPLATE}" == *"<!-- Diff files - START -->"* && "${TEMPLATE}" == *"<!-- Diff files - END -->"* ) ]]; then
    REPLACE_FILES="true"
  fi

  echo "Detected diff markers: summary=${REPLACE_SUMMARY} commits=${REPLACE_COMMITS} files=${REPLACE_FILES}"

  if [[ "${REPLACE_SUMMARY}" == "true" || "${REPLACE_COMMITS}" == "true" || "${REPLACE_FILES}" == "true" ]]; then
    TEMPLATE_WORK_FILE="/tmp/template-work.md"
    SUMMARY_FILE="/tmp/template-summary.txt"
    COMMITS_FILE="/tmp/template-commits.txt"
    FILES_FILE="/tmp/template-files.txt"

    printf '%s' "${TEMPLATE}" > "${TEMPLATE_WORK_FILE}"

    if [[ "${REPLACE_SUMMARY}" == "true" ]]; then
      get_git_summary
      printf '%s' "${GIT_SUMMARY}" > "${SUMMARY_FILE}"
      apply_line_cap "${SUMMARY_FILE}" "${MAX_DIFF_LINES}" "Diff summary"
    fi
    if [[ "${REPLACE_COMMITS}" == "true" ]]; then
      get_git_log
      printf '%s' "${GIT_LOG}" > "${COMMITS_FILE}"
      apply_line_cap "${COMMITS_FILE}" "${MAX_DIFF_LINES}" "Diff commits"
    fi
    if [[ "${REPLACE_FILES}" == "true" ]]; then
      get_git_diff
      printf '%s' "${GIT_DIFF}" > "${FILES_FILE}"
      apply_line_cap "${FILES_FILE}" "${MAX_DIFF_LINES}" "Diff files"
    fi

    "${REPLACE_TEMPLATE_SCRIPT}" \
      --template "${TEMPLATE_WORK_FILE}" \
      --summary-file "${SUMMARY_FILE}" \
      --commits-file "${COMMITS_FILE}" \
      --files-file "${FILES_FILE}" \
      --replace-summary "${REPLACE_SUMMARY}" \
      --replace-commits "${REPLACE_COMMITS}" \
      --replace-files "${REPLACE_FILES}"

    TEMPLATE=$(cat "${TEMPLATE_WORK_FILE}")
  else
    echo -e "[INFO] No diff markers found in template body. Skipping get_diff replacements."
  fi
fi

if [[ -z "${PR_NUMBER}" ]]; then
  echo -e "\nSetting all arguments..."
  if [[ -n "${INPUT_TITLE}" ]]; then
    TITLE=$(echo -e "${INPUT_TITLE}" | head -1)
  else
    TITLE=$(git log -1 --pretty=%s | head -1)
  fi
else
  echo -e "${TEMPLATE}" > /tmp/template
fi

printf '%s' "${TEMPLATE}" > "/tmp/template-final.md"
apply_body_limits "/tmp/template-final.md" "${MAX_BODY_BYTES}" "${MAX_COMMENT_BODY_BYTES}"
TEMPLATE="$(cat "${OVERFLOW_MAIN_FILE}")"
printf '%s' "${TEMPLATE}" > /tmp/template

FINAL_BODY_BYTES="$(wc -c < /tmp/template | tr -d '[:space:]')"
echo "Final main body size (bytes): ${FINAL_BODY_BYTES}"
echo "Managed overflow chunks: ${CHUNK_COUNT}"

if [[ -z "${PR_NUMBER}" ]]; then
  GH_CREATE_ARGS=(
    --repo "${TARGET_REPOSITORY}"
    --base "${TARGET_BRANCH}"
    --head "${TARGET_OWNER}:${SOURCE_BRANCH}"
    --title "${TITLE}"
    --body-file /tmp/template
  )
  append_csv_arg --reviewer "${INPUT_REVIEWER}" GH_CREATE_ARGS
  append_csv_arg --assignee "${INPUT_ASSIGNEE}" GH_CREATE_ARGS
  append_csv_arg --label "${INPUT_LABEL}" GH_CREATE_ARGS
  milestone_value="$(trim_whitespace "${INPUT_MILESTONE}")"
  if [[ -n "${milestone_value}" ]]; then
    GH_CREATE_ARGS+=(--milestone "${milestone_value}")
  fi
  if [[ "${INPUT_DRAFT}" ==  "true" ]]; then
    GH_CREATE_ARGS+=(--draft)
  fi

  echo -e "\nCreating pull request"
  echo -e "\nTemplate:"
  cat /tmp/template
  echo -e "\nRunning: gh pr create --repo ${TARGET_REPOSITORY} --base ${TARGET_BRANCH} --head ${TARGET_OWNER}:${SOURCE_BRANCH} ..."
  URL="$(gh pr create "${GH_CREATE_ARGS[@]}")"
  # shellcheck disable=SC2181
  if [[ "$?" != "0" ]]; then RET_CODE=1; fi
  PR_NUMBER="$(gh pr view "${URL}" --repo "${TARGET_REPOSITORY}" --json number --jq '.number')"
  if (( CHUNK_COUNT > 0 )); then
    reconcile_managed_comments "${PR_NUMBER}" "${CHUNK_COUNT}"
  fi
else
  echo -e "\nUpdating pull request"
  echo -e "Running: gh api --method PATCH repos/${TARGET_REPOSITORY}/pulls/${PR_NUMBER} --field body=@/tmp/template"
  URL="$(gh api --method PATCH "repos/${TARGET_REPOSITORY}/pulls/${PR_NUMBER}" --field "body=@/tmp/template" --jq '.html_url')"
  # shellcheck disable=SC2181
  if [[ "$?" != "0" ]]; then RET_CODE=1; fi
  if (( CHUNK_COUNT > 0 )); then
    reconcile_managed_comments "${PR_NUMBER}" "${CHUNK_COUNT}"
  else
    reconcile_managed_comments "${PR_NUMBER}" "0"
  fi
fi

# Finish
{
  echo "url=${URL}"
  echo "pr_number=${PR_NUMBER}"
} >> "$GITHUB_OUTPUT"
if [[ ${RET_CODE} != "0" ]]; then
  echo -e "\n[ERROR] Check log for errors."
  exit 1
else
  # Pass in other cases
  echo -e "\n[INFO] No errors found."
  echo -e "\n[INFO] See the pull request: ${URL}"
  exit 0
fi
