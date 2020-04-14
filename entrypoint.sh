#!/usr/bin/env bash

set -e

# Return code
RET_CODE=0

# Run main action
echo "[INFO] Env var BAR: ${BAR}"
echo "[INFO] Input var BAZ: ${INPUT_BAZ}"
RET_CODE=$?

# Finish
echo "::set-output name=foobar::${INPUT_BAZ}"
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
  exit 0
fi
