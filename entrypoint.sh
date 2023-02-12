#!/usr/bin/env bash

set -e

# Return code
RET_CODE=0

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

echo -e "\nComparing branches by revisions..."
if [[ $(git rev-parse --revs-only "${SOURCE_BRANCH}") == $(git rev-parse --revs-only "${TARGET_BRANCH}") ]]; then
  echo -e "\n[INFO] Both branches are the same. No action needed."
  exit 0
fi

echo -e "\nComparing branches by diff..."
if [[ -z $(git diff "remotes/origin/${TARGET_BRANCH}...remotes/origin/${SOURCE_BRANCH}") ]]; then
  if [[ "${INPUT_ALLOW_NO_DIFF}" == "true" ]]; then
    echo -e "\n[INFO] Both branches are the same. Continuing."
  else
    echo -e "\n[INFO] Both branches are the same. No action needed."
    exit 0
  fi
fi

# sed has problems with putting multi-line strings in the next steps, and later we use # for sed
# newline `\n` and hash `#` characters are replaced with some (hopefully) totally unlikely strings
# after insertions of git information into template those strings are replaced back by proper characters

echo -e "\nListing new commits in the source branch..."
git log --graph --pretty=format:'%Cred%h%Creset - %Cblue%an%Creset - %Cgreen%cd%Creset %n%s %b' --abbrev-commit --date=format:'%Y-%m-%d %H:%M:%S' "origin/${TARGET_BRANCH}...origin/${SOURCE_BRANCH}"
GIT_LOG=$(git log --graph --pretty=format:'%Cred%h%Creset - %Cblue%an%Creset - %Cgreen%cd%Creset %n%s%n%b' --abbrev-commit --date=format:'%Y-%m-%d %H:%M:%S' --no-color "origin/${TARGET_BRANCH}...origin/${SOURCE_BRANCH}")
GIT_LOG=$(echo -e "${GIT_LOG}" | sed 's|#|^HaSz^|g' | sed ':a;N;$!ba; s/\n/^NowALiNiA^/g')

echo -e "\n\nListing commits subjects in the source branch..."
git log --reverse --pretty=format:'%s' --abbrev-commit "origin/${TARGET_BRANCH}...origin/${SOURCE_BRANCH}"
GIT_SUMMARY=$(git log --reverse --pretty=format:'%s' --abbrev-commit "origin/${TARGET_BRANCH}...origin/${SOURCE_BRANCH}")
GIT_SUMMARY=$(echo -e "${GIT_SUMMARY}" | sed 's|#|^HaSz^|g' | sed ':a;N;$!ba; s/\n/^NowALiNiA^/g')

echo -e "\n\nListing files modified in the source branch..."
git diff --compact-summary "origin/${TARGET_BRANCH}...origin/${SOURCE_BRANCH}"
GIT_DIFF=$(git diff --compact-summary --no-color "origin/${TARGET_BRANCH}...origin/${SOURCE_BRANCH}")
GIT_DIFF=$(echo -e "${GIT_DIFF}" | sed 's|#|^HaSz^|g' | sed ':a;N;$!ba; s/\n/^NowALiNiA^/g')

echo -e "\nSetting template..."
PR_NUMBER=$(hub pr list --base "${TARGET_BRANCH}" --head "${SOURCE_BRANCH}" --format '%I')
if [[ -z "${PR_NUMBER}" ]]; then
  if [[ -n "${INPUT_TEMPLATE}" ]]; then
    TEMPLATE=$(cat "${INPUT_TEMPLATE}")
  elif [[ -n "${INPUT_BODY}" ]]; then
    TEMPLATE="${INPUT_BODY}"
  else
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
    TEMPLATE=${TEMPLATE/${OLD_STRING}/${GIT_SUMMARY}}
  fi
fi

if [[ "${INPUT_GET_DIFF}" ==  "true" ]]; then
  echo -e "\nReplacing predefined fields with git information..."
  # little hack to trick sed to work with multiline
  # also backwards compatible with old replacement strings
  TEMPLATE=$(echo -e "${TEMPLATE}" | sed ':a;N;$!ba; s#<!-- Diff summary - START -->.*<!-- Diff summary - END -->#<!-- Diff summary - START -->\n'"${GIT_SUMMARY}"'\n<!-- Diff summary - END -->#g')
  TEMPLATE=$(echo -e "${TEMPLATE}" | sed ':a;N;$!ba; s#<!-- Diff commits -->#<!-- Diff commits - START -->\n'"${GIT_LOG}"'\n<!-- Diff commits - END -->#g')
  TEMPLATE=$(echo -e "${TEMPLATE}" | sed ':a;N;$!ba; s#<!-- Diff commits - START -->.*<!-- Diff commits - END -->#<!-- Diff commits - START -->\n'"${GIT_LOG}"'\n<!-- Diff commits - END -->#g')
  TEMPLATE=$(echo -e "${TEMPLATE}" | sed ':a;N;$!ba; s#<!-- Diff files -->#<!-- Diff files - START -->\n'"${GIT_DIFF}"'\n<!-- Diff files - END -->#g')
  TEMPLATE=$(echo -e "${TEMPLATE}" | sed ':a;N;$!ba; s#<!-- Diff files - START -->.*<!-- Diff files - END -->#<!-- Diff files - START -->\n'"${GIT_DIFF}"'\n<!-- Diff files - END -->#g')
fi
TEMPLATE=$(echo -e "${TEMPLATE}" | sed 's|\^HaSz\^|#|g' | sed '1h;2,$H;$!d;g; s|\^NowALiNiA\^|\n|g')

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
  PR_NUMBER=$(gh pr view --json number -q .number ${URL})
  # shellcheck disable=SC2181
  if [[ "$?" != "0" ]]; then RET_CODE=1; fi
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
