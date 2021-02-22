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
echo "  old_string: ${INPUT_OLD_STRING}"
echo "  new_string: ${INPUT_NEW_STRING}"
echo "  get_diff: ${INPUT_GET_DIFF}"

echo -e "\nSetting branches..."
SOURCE_BRANCH="${INPUT_SOURCE_BRANCH:-$(git symbolic-ref --short -q HEAD)}"
TARGET_BRANCH="${INPUT_TARGET_BRANCH:-master}"
echo "Source branch: ${SOURCE_BRANCH}"
echo "Target branch: ${TARGET_BRANCH}"

# Require github_token
if [[ -z "${INPUT_GITHUB_TOKEN}" ]]; then
  # shellcheck disable=SC2016
  MESSAGE='Missing input "github_token: ${{ secrets.GITHUB_TOKEN }}".'
  echo "[ERROR] ${MESSAGE}"
  exit 1
fi

echo -e "\nSetting GitHub credentials..."
git remote set-url origin "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}"
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
# Needed for hub binary
export GITHUB_USER="${GITHUB_ACTOR}"

#echo -e "\nUpdating all branches..."
#git fetch origin '+refs/heads/*:refs/heads/*' --update-head-ok

echo -e "\nComparing branches by revisions..."
if [[ $(git rev-parse --revs-only "${SOURCE_BRANCH}") == $(git rev-parse --revs-only "${TARGET_BRANCH}") ]]; then
  echo -e "\n[INFO] Both branches are the same. No action needed."
  exit 0
fi

echo -e "\nComparing branches by diff..."
if [[ -z $(git diff "remotes/origin/${TARGET_BRANCH}..remotes/origin/${SOURCE_BRANCH}") ]]; then
  echo -e "\n[INFO] Both branches are the same. No action needed."
  exit 0
fi

# Try remote branches
SOURCE_BRANCH_R=$(git branch -r | grep "${SOURCE_BRANCH}" | grep -v origin/HEAD | xargs)
TARGET_BRANCH_R=$(git branch -r | grep "${TARGET_BRANCH}" | grep -v origin/HEAD | xargs)

echo -e "\n\nListing new commits in the source branch..."
git log --graph --pretty=format:'%Cred%h%Creset - %Cblue%an%Creset - %Cgreen%cr%Creset %n%s %b' --abbrev-commit "remotes/origin/${TARGET_BRANCH}..remotes/origin/${SOURCE_BRANCH}"
GITLOG=$(git log --graph --pretty=format:'%Cred%h%Creset - %Cblue%an%Creset - %Cgreen%cr%Creset %n%s %b' --abbrev-commit --no-color "${TARGET_BRANCH_R}..${SOURCE_BRANCH_R}")

echo -e "\n\nListing files modified in the source branch..."
git diff --compact-summary "remotes/origin/${TARGET_BRANCH}..remotes/origin/${SOURCE_BRANCH}"
GITDIFF=$(git diff --compact-summary --no-color "remotes/origin/${TARGET_BRANCH}..remotes/origin/${SOURCE_BRANCH}")

echo -e "\nReplacing strings in the template..."
if [[ -f "${INPUT_TEMPLATE}" ]]; then
  if [[ -n "${INPUT_OLD_STRING}" ]]; then
    TEMPLATE=$(cat "${INPUT_TEMPLATE}")
    OLD_STRING=${INPUT_OLD_STRING/\!/\\!}
    TEMPLATE=${TEMPLATE/${OLD_STRING}/${INPUT_NEW_STRING}}
  fi
  if [[ "${INPUT_GET_DIFF}" ==  "true" ]]; then
    TEMPLATE="${TEMPLATE/<\!-- Diff commits -->/${GITLOG}}"
    TEMPLATE="${TEMPLATE/<\!-- Diff files -->/${GITDIFF}}"
  fi
fi

echo -e "\nSetting title and body..."
if [[ -n "${INPUT_TITLE}" ]]; then
  TITLE="${INPUT_TITLE}"
else
  TITLE="$(git log -1 --pretty=%s | head -1)"
fi
if [[ -n "${INPUT_TEMPLATE}" ]]; then
  BODY="${TEMPLATE}"
elif [[ -n "${INPUT_BODY}" ]]; then
  BODY="${INPUT_BODY}"
else
  BODY="$(git log -1 --pretty=%B)"
fi
echo "${BODY}" > /tmp/body
ARG_LIST="-m \"${TITLE}\" -m \"@/tmp/body\""

echo -e "\nSetting other arguments..."
if [[ -n "${INPUT_REVIEWER}" ]]; then
  ARG_LIST="${ARG_LIST} -r \"${INPUT_REVIEWER}\""
fi

if [[ -n "${INPUT_ASSIGNEE}" ]]; then
  ARG_LIST="${ARG_LIST} -a \"${INPUT_ASSIGNEE}\""
fi

if [[ -n "${INPUT_LABEL}" ]]; then
  ARG_LIST="${ARG_LIST} -l \"${INPUT_LABEL}\""
fi

if [[ -n "${INPUT_MILESTONE}" ]]; then
  ARG_LIST="${ARG_LIST} -M \"${INPUT_MILESTONE}\""
fi

if [[ "${INPUT_DRAFT}" ==  "true" ]]; then
  ARG_LIST="${ARG_LIST} -d"
fi

echo -e "\nChecking if pull request exists..."
PR_NUMBER=$(hub pr list --head dependency/codebuild-test --format '%I')
if [[ -z "${PR_NUMBER}" ]]; then
  echo -e "\nCreating pull request"
  COMMAND="hub pull-request -b ${TARGET_BRANCH} -h ${SOURCE_BRANCH} --no-edit ${ARG_LIST} || true"
  echo -e "Running: ${COMMAND}"
  URL=$(sh -c "${COMMAND}")
  # shellcheck disable=SC2181
  if [[ "$?" != "0" ]]; then RET_CODE=1; fi
else
  echo -e "\nUpdating pull request"
  COMMAND="hub api --method PATCH repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER} --raw-field 'body=@/tmp/body' || true"
  echo -e "Running: ${COMMAND}"
  URL=$(sh -c "${COMMAND}")
  # shellcheck disable=SC2181
  if [[ "$?" != "0" ]]; then RET_CODE=1; fi
fi

# Finish
echo "::set-output name=url::${URL}"
if [[ ${RET_CODE} != "0" ]]; then
  echo -e "\n[ERROR] Check log for errors."
  exit 1
else
  # Pass in other cases
  echo -e "\n[INFO] No errors found."
  echo -e "\n[INFO] See the pull request: ${URL}"
  exit 0
fi
