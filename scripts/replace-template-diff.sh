#!/usr/bin/env bash

set -Eeuo pipefail

TEMPLATE_FILE=""
SUMMARY_FILE=""
COMMITS_FILE=""
FILES_FILE=""
REPLACE_SUMMARY="false"
REPLACE_COMMITS="false"
REPLACE_FILES="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)
      TEMPLATE_FILE="$2"
      shift 2
      ;;
    --summary-file)
      SUMMARY_FILE="$2"
      shift 2
      ;;
    --commits-file)
      COMMITS_FILE="$2"
      shift 2
      ;;
    --files-file)
      FILES_FILE="$2"
      shift 2
      ;;
    --replace-summary)
      REPLACE_SUMMARY="$2"
      shift 2
      ;;
    --replace-commits)
      REPLACE_COMMITS="$2"
      shift 2
      ;;
    --replace-files)
      REPLACE_FILES="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TEMPLATE_FILE" ]]; then
  echo "[ERROR] Missing required argument: --template" >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "[ERROR] Template file does not exist: $TEMPLATE_FILE" >&2
  exit 1
fi

if [[ "$REPLACE_SUMMARY" == "true" && ( -z "$SUMMARY_FILE" || ! -f "$SUMMARY_FILE" ) ]]; then
  echo "[ERROR] Summary replacement requested but file is missing" >&2
  exit 1
fi

if [[ "$REPLACE_COMMITS" == "true" && ( -z "$COMMITS_FILE" || ! -f "$COMMITS_FILE" ) ]]; then
  echo "[ERROR] Commits replacement requested but file is missing" >&2
  exit 1
fi

if [[ "$REPLACE_FILES" == "true" && ( -z "$FILES_FILE" || ! -f "$FILES_FILE" ) ]]; then
  echo "[ERROR] Files replacement requested but file is missing" >&2
  exit 1
fi

REPLACE_SUMMARY="$REPLACE_SUMMARY" \
REPLACE_COMMITS="$REPLACE_COMMITS" \
REPLACE_FILES="$REPLACE_FILES" \
SUMMARY_FILE="$SUMMARY_FILE" \
COMMITS_FILE="$COMMITS_FILE" \
FILES_FILE="$FILES_FILE" \
perl -0777 -i -pe '
  BEGIN {
    sub read_file {
      my ($path) = @_;
      return q{} if !defined($path) || $path eq q{};
      open my $fh, q{<}, $path or die "Unable to read replacement file: $path\n";
      local $/;
      my $content = <$fh>;
      close $fh;
      return defined($content) ? $content : q{};
    }

    $summary = $ENV{REPLACE_SUMMARY} eq q{true} ? read_file($ENV{SUMMARY_FILE}) : q{};
    $commits = $ENV{REPLACE_COMMITS} eq q{true} ? read_file($ENV{COMMITS_FILE}) : q{};
    $files = $ENV{REPLACE_FILES} eq q{true} ? read_file($ENV{FILES_FILE}) : q{};
  }

  if ($ENV{REPLACE_SUMMARY} eq q{true}) {
    s{<!-- Diff summary - START -->.*?<!-- Diff summary - END -->}{"<!-- Diff summary - START -->\n$summary\n<!-- Diff summary - END -->"}gse;
  }

  if ($ENV{REPLACE_COMMITS} eq q{true}) {
    s{<!-- Diff commits -->}{"<!-- Diff commits - START -->\n$commits\n<!-- Diff commits - END -->"}gse;
    s{<!-- Diff commits - START -->.*?<!-- Diff commits - END -->}{"<!-- Diff commits - START -->\n$commits\n<!-- Diff commits - END -->"}gse;
  }

  if ($ENV{REPLACE_FILES} eq q{true}) {
    s{<!-- Diff files -->}{"<!-- Diff files - START -->\n$files\n<!-- Diff files - END -->"}gse;
    s{<!-- Diff files - START -->.*?<!-- Diff files - END -->}{"<!-- Diff files - START -->\n$files\n<!-- Diff files - END -->"}gse;
  }
' "$TEMPLATE_FILE"
