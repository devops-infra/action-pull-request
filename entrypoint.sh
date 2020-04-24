#!/usr/bin/env bash

set -e

# Return code
RET_CODE=0

echo "Inputs:"
echo "  target_branch: ${INPUT_TARGET_BRANCH}"
echo "  title:   ${INPUT_TITLE}"
echo "  template: ${INPUT_TEMPLATE}"
echo "  body: ${INPUT_BODY}"
echo "  reviewer: ${INPUT_REVIEWER}"
echo "  assignee: ${INPUT_ASSIGNEE}"
echo "  label: ${INPUT_LABEL}"
echo "  milestone: ${INPUT_MILESTONE}"
echo "  draft: ${INPUT_DRAFT}"
echo " "


# Set branches
SOURCE_BRANCH=$(git symbolic-ref --short -q HEAD)
TARGET_BRANCH="${INPUT_TARGET_BRANCH:-"master"}"
echo "Source branch: ${SOURCE_BRANCH}"
echo "Target branch: ${TARGET_BRANCH}"

# Required github_token
if [[ -z "${INPUT_GITHUB_TOKEN}" ]]; then
  MESSAGE='Missing input "github_token: ${{ secrets.GITHUB_TOKEN }}".'
  echo "[ERROR] ${MESSAGE}"
  exit 1
fi

# Set GitHub credentials
git remote set-url origin "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}"
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
# Needed for hub binary
export GITHUB_USER="${GITHUB_ACTOR}"

# Update all branches
git fetch origin '+refs/heads/*:refs/heads/*' --update-head-ok
# Compare branches by revisions
if [[ $(git rev-parse --revs-only "${SOURCE_BRANCH}") == $(git rev-parse --revs-only "${TARGET_BRANCH}") ]]; then
  echo "[INFO] Both branches are the same. No action needed."
  exit 0
fi

# Compare branches by diff
if [[ -z $(git diff "${SOURCE_BRANCH}..${TARGET_BRANCH}") ]]; then
  echo "[INFO] Both branches are the same. No action needed."
  exit 0
fi

# Get new commits in the source branch
echo "[INFO] Commits in this pull request:"
git log --graph --pretty=format:'%Cred%h%Creset - %Cblue%an%Creset - %Cgreen%cr%Creset %n%s %b' --abbrev-commit --date=relative "${TARGET_BRANCH}..${SOURCE_BRANCH}"
GITLOG=$(git log --graph --pretty=format:'%Cred%h%Creset - %Cblue%an%Creset - %Cgreen%cr%Creset %n%s %b' --abbrev-commit --date=relative --no-color "${TARGET_BRANCH}..${SOURCE_BRANCH}")
echo " "

# List files modified in those commits
echo "[INFO] Files modified:"
git diff --compact-summary "${TARGET_BRANCH}..${SOURCE_BRANCH}"
GITDIFF=$(git diff --compact-summary --no-color "${TARGET_BRANCH}..${SOURCE_BRANCH}")
echo " "

# Set title and/or body
ARG_LIST="${INPUT_TITLE}"
if [[ -n "${ARG_LIST}" ]]; then
  ARG_LIST="-m \"${ARG_LIST}\""
  if [[ -n "${INPUT_TEMPLATE}" ]]; then
    sed -i 's/`/\\`/g; s/\$/\\\$/g' "${INPUT_TEMPLATE}"
    ARG_LIST="${ARG_LIST} -m \"$(echo -e "$(cat "${INPUT_TEMPLATE}")")\""
  elif [[ -n "${INPUT_BODY}" ]]; then
    ARG_LIST="${ARG_LIST} -m \"${INPUT_BODY}\""
  fi
fi

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

# Main action
COMMAND="hub pull-request -b ${TARGET_BRANCH} -h ${SOURCE_BRANCH} --no-edit ${ARG_LIST} || true"
echo "Running: $COMMAND"
URL=$(sh -c "$COMMAND")
if [[ "$?" != "0" ]]; then
  RET_CODE=1
fi

# Finish
echo "::set-output name=url::${URL}"
if [[ ${RET_CODE} != "0" ]]; then
  echo " "
  echo "[ERROR] Check log for errors."
  echo " "
  exit 1
else
  # Pass in other cases
  echo " "
  echo "[INFO] No errors found."
  echo " "
  echo "[INFO] See the pull request: ${URL}"
  echo " "
  exit 0
fi
