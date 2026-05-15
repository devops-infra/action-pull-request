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

REPLACE_TEMPLATE_SCRIPT="/scripts/replace-template-diff.sh"
if [[ ! -x "${REPLACE_TEMPLATE_SCRIPT}" ]]; then
  REPLACE_TEMPLATE_SCRIPT="$(dirname "$0")/scripts/replace-template-diff.sh"
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

echo "Inputs:"
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

echo -e "\nSetting GitHub credentials..."
# Prevents issues with: fatal: unsafe repository ('/github/workspace' is owned by someone else)
git config --global --add safe.directory "${GITHUB_WORKSPACE}"
git config --global --add safe.directory /github/workspace
git remote set-url origin "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}"
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
# Needed for hub binary
export GITHUB_USER="${GITHUB_ACTOR}"

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
PR_NUMBER=$(hub pr list --base "${TARGET_BRANCH}" --head "${SOURCE_BRANCH}" --format '%I')
if [[ -z "${PR_NUMBER}" ]]; then
  if [[ -n "${INPUT_TEMPLATE}" ]]; then
    TEMPLATE=$(cat "${INPUT_TEMPLATE}")
  elif [[ -n "${INPUT_BODY}" ]]; then
    TEMPLATE="${INPUT_BODY}"
  else
    get_git_log
    TEMPLATE="${GIT_LOG}"
  fi
else
  TEMPLATE=$(hub api --method GET "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}" | jq -r '.body')
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

  if [[ "${REPLACE_SUMMARY}" == "true" || "${REPLACE_COMMITS}" == "true" || "${REPLACE_FILES}" == "true" ]]; then
    TEMPLATE_WORK_FILE="/tmp/template-work.md"
    SUMMARY_FILE="/tmp/template-summary.txt"
    COMMITS_FILE="/tmp/template-commits.txt"
    FILES_FILE="/tmp/template-files.txt"

    printf '%s' "${TEMPLATE}" > "${TEMPLATE_WORK_FILE}"

    if [[ "${REPLACE_SUMMARY}" == "true" ]]; then
      get_git_summary
      printf '%s' "${GIT_SUMMARY}" > "${SUMMARY_FILE}"
    fi
    if [[ "${REPLACE_COMMITS}" == "true" ]]; then
      get_git_log
      printf '%s' "${GIT_LOG}" > "${COMMITS_FILE}"
    fi
    if [[ "${REPLACE_FILES}" == "true" ]]; then
      get_git_diff
      printf '%s' "${GIT_DIFF}" > "${FILES_FILE}"
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
  ARG_LIST=()
  ARG_LIST+=("-F /tmp/template")
  if [[ -n "${INPUT_REVIEWER}" ]]; then
    ARG_LIST+=("-r \"${INPUT_REVIEWER}\"")
  fi
  if [[ -n "${INPUT_ASSIGNEE}" ]]; then
    ARG_LIST+=("-a \"${INPUT_ASSIGNEE}\"")
  fi
  if [[ -n "${INPUT_LABEL}" ]]; then
    ARG_LIST+=("-l \"${INPUT_LABEL}\"")
  fi
  if [[ -n "${INPUT_MILESTONE}" ]]; then
    ARG_LIST+=("-M \"${INPUT_MILESTONE}\"")
  fi
  if [[ "${INPUT_DRAFT}" ==  "true" ]]; then
    ARG_LIST+=("-d")
  fi
else
  echo -e "${TEMPLATE}" > /tmp/template
fi

if [[ -z "${PR_NUMBER}" ]]; then
  echo -e "\nCreating pull request"
  echo -e "${TITLE}" > /tmp/template
  echo -e "\n${TEMPLATE}" >> /tmp/template
  echo -e "\nTemplate:"
  cat /tmp/template
  # shellcheck disable=SC2016,SC2124
  COMMAND="hub pull-request -b ${TARGET_BRANCH} -h ${SOURCE_BRANCH} --no-edit ${ARG_LIST[@]}"
  echo -e "\nRunning: ${COMMAND}"
  URL=$(sh -c "${COMMAND}")
  # shellcheck disable=SC2181
  if [[ "$?" != "0" ]]; then RET_CODE=1; fi
  PR_NUMBER=$(gh pr view --json number -q .number "${URL}")
else
  echo -e "\nUpdating pull request"
  COMMAND="hub api --method PATCH repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER} --field 'body=@/tmp/template'"
  echo -e "Running: ${COMMAND}"
  URL=$(sh -c "${COMMAND} | jq -r '.html_url'")
  # shellcheck disable=SC2181
  if [[ "$?" != "0" ]]; then RET_CODE=1; fi
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
