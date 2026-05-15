#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(dirname "$0")/../../scripts/replace-template-diff.sh"

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

assert_not_contains() {
  local file_path="$1"
  local not_expected="$2"
  if grep -Fq -- "${not_expected}" "${file_path}"; then
    echo "Assertion failed. Did not expect to find: ${not_expected}" >&2
    echo "----- FILE CONTENT -----" >&2
    cat "${file_path}" >&2
    exit 1
  fi
}

run_replacement() {
  local template_file="$1"
  local replace_summary="$2"
  local replace_commits="$3"
  local replace_files="$4"

  "${SCRIPT_PATH}" \
    --template "${template_file}" \
    --summary-file "${TMP_DIR}/summary.txt" \
    --commits-file "${TMP_DIR}/commits.txt" \
    --files-file "${TMP_DIR}/files.txt" \
    --replace-summary "${replace_summary}" \
    --replace-commits "${replace_commits}" \
    --replace-files "${replace_files}"
}

cat > "${TMP_DIR}/summary.txt" <<'EOF'
Summary line 1
Summary line 2
EOF

cat > "${TMP_DIR}/commits.txt" <<'EOF'
abc123 - commit one
def456 - commit two
EOF

cat > "${TMP_DIR}/files.txt" <<'EOF'
M README.md
A scripts/new.sh
EOF

cat > "${TMP_DIR}/template-full.md" <<'EOF'
Body start
<!-- Diff summary - START -->
old summary
<!-- Diff summary - END -->
<!-- Diff commits -->
<!-- Diff files - START -->
old files
<!-- Diff files - END -->
Body end
EOF

run_replacement "${TMP_DIR}/template-full.md" "true" "true" "true"

assert_contains "${TMP_DIR}/template-full.md" "Summary line 1"
assert_contains "${TMP_DIR}/template-full.md" "abc123 - commit one"
assert_contains "${TMP_DIR}/template-full.md" "M README.md"
assert_contains "${TMP_DIR}/template-full.md" "<!-- Diff commits - START -->"
assert_contains "${TMP_DIR}/template-full.md" "<!-- Diff files - END -->"
assert_not_contains "${TMP_DIR}/template-full.md" "old summary"
assert_not_contains "${TMP_DIR}/template-full.md" "old files"

cat > "${TMP_DIR}/template-commits-block.md" <<'EOF'
Body start
<!-- Diff commits - START -->
legacy
<!-- Diff commits - END -->
Body end
EOF

run_replacement "${TMP_DIR}/template-commits-block.md" "false" "true" "false"

assert_contains "${TMP_DIR}/template-commits-block.md" "def456 - commit two"
assert_not_contains "${TMP_DIR}/template-commits-block.md" "legacy"

cat > "${TMP_DIR}/template-no-markers.md" <<'EOF'
No markers here.
EOF

run_replacement "${TMP_DIR}/template-no-markers.md" "false" "false" "false"

assert_contains "${TMP_DIR}/template-no-markers.md" "No markers here."

python3 - <<'PY' > "${TMP_DIR}/commits-large.txt"
for i in range(15000):
    print(f"{i:05d} - synthetic commit line with payload")
PY

cat > "${TMP_DIR}/template-large.md" <<'EOF'
Large body start
<!-- Diff commits -->
Large body end
EOF

"${SCRIPT_PATH}" \
  --template "${TMP_DIR}/template-large.md" \
  --summary-file "${TMP_DIR}/summary.txt" \
  --commits-file "${TMP_DIR}/commits-large.txt" \
  --files-file "${TMP_DIR}/files.txt" \
  --replace-summary "false" \
  --replace-commits "true" \
  --replace-files "false"

assert_contains "${TMP_DIR}/template-large.md" "14999 - synthetic commit line with payload"

echo "All replace-template-diff tests passed."
