#!/usr/bin/env bash
set -euo pipefail

# changelog-prep.sh - Deterministic changelog preparation script
#
# Finds new commits since the last changelog update and outputs a structured
# manifest. Used by the changelog skill (SKILL.md) to separate mechanical
# work (this script) from creative work (Claude).
#
# Usage:
#   bash changelog-prep.sh                   # default: commits since last changelog update
#   bash changelog-prep.sh --preview         # same, but signals preview mode
#   bash changelog-prep.sh day               # commits from last 24 hours
#   bash changelog-prep.sh week              # commits from last 7 days
#   bash changelog-prep.sh month             # commits from last 30 days
#   bash changelog-prep.sh 3d               # commits from last N days
#   bash changelog-prep.sh --since-tag v1.0  # commits since a git tag
#
# Output: structured key=value manifest to stdout

# ── 1. Auto-detect changelog file ────────────────────────────────────────────

CHANGELOG=""
for candidate in "src/data/changelog.ts" "data/changelog.ts"; do
  if [[ -f "$candidate" ]]; then
    CHANGELOG="$candidate"
    break
  fi
done

if [[ -z "$CHANGELOG" ]]; then
  CHANGELOG=$(grep -rl "changelogReleases" --include="*.ts" . 2>/dev/null | head -1 || echo "")
fi

if [[ -z "$CHANGELOG" ]]; then
  echo "ERROR=No changelog file found. Create one first or check the project structure."
  exit 0
fi

# ── 2. Parse last version + date ─────────────────────────────────────────────

LAST_VERSION=$(grep -m1 "version:" "$CHANGELOG" | sed "s/.*'\([^']*\)'.*/\1/" || echo "")
LAST_DATE=$(grep -m1 "date:" "$CHANGELOG" | sed "s/.*'\([^']*\)'.*/\1/" || echo "")

if [[ -z "$LAST_VERSION" ]]; then
  # Empty changelog array - first run
  LAST_VERSION="0.0.0"
  LAST_DATE=""
fi

# ── 3. Find commit boundary ──────────────────────────────────────────────────
# This is the core fix: use the exact commit that last modified the changelog
# file as the anchor point, instead of a date-based range that can re-include
# commits already processed into the previous release.

BOUNDARY_SHA=$(git log -1 --format=%H -- "$CHANGELOG" 2>/dev/null || echo "")

# ── 4. Parse arguments ───────────────────────────────────────────────────────

PREVIEW="false"
TIME_ARG=""
SINCE_TAG=""
prev_arg=""

for arg in "$@"; do
  case "$arg" in
    --preview) PREVIEW="true" ;;
    --since-tag) ;;  # next arg is the tag name
    day|week|month) TIME_ARG="$arg" ;;
    *d)
      # Match patterns like 3d, 7d, 14d (digits followed by d)
      if [[ "$arg" =~ ^[0-9]+d$ ]]; then
        TIME_ARG="$arg"
      fi
      ;;
    *)
      if [[ "$prev_arg" == "--since-tag" ]]; then
        SINCE_TAG="$arg"
      fi
      ;;
  esac
  prev_arg="$arg"
done

# ── 5. Get commits ───────────────────────────────────────────────────────────
# Priority: explicit time args > commit SHA boundary > all commits (first run)

if [[ -n "$SINCE_TAG" ]]; then
  COMMITS=$(git log "${SINCE_TAG}..HEAD" --pretty=format:'%h|%as|%s' --no-merges --reverse 2>/dev/null || echo "")
elif [[ -n "$TIME_ARG" ]]; then
  case "$TIME_ARG" in
    day)   COMMITS=$(git log --since='1 day ago' --pretty=format:'%h|%as|%s' --no-merges --reverse) ;;
    week)  COMMITS=$(git log --since='1 week ago' --pretty=format:'%h|%as|%s' --no-merges --reverse) ;;
    month) COMMITS=$(git log --since='1 month ago' --pretty=format:'%h|%as|%s' --no-merges --reverse) ;;
    *d)    DAYS="${TIME_ARG%d}"
           COMMITS=$(git log --since="${DAYS} days ago" --pretty=format:'%h|%as|%s' --no-merges --reverse) ;;
  esac
elif [[ -n "$BOUNDARY_SHA" ]]; then
  # Default: commit SHA boundary (precise, no date overlap possible)
  COMMITS=$(git log "${BOUNDARY_SHA}..HEAD" --pretty=format:'%h|%as|%s' --no-merges --reverse 2>/dev/null || echo "")
else
  # First run fallback: no changelog commit exists yet
  COMMITS=$(git log --pretty=format:'%h|%as|%s' --no-merges --reverse)
fi

if [[ -z "$COMMITS" ]]; then
  echo "ERROR=No new commits found since last changelog update."
  exit 0
fi

# ── 6. Filter by conventional commit prefix ──────────────────────────────────
# INCLUDED: auto-include (clear user-visible impact)
# REVIEW:   pass to Claude for judgment (may or may not be user-visible)

INCLUDED=$(echo "$COMMITS" | grep -E '\|(feat|fix|perf|style|ui|design)(\(.+\))?!?:' || echo "")
REVIEW=$(echo "$COMMITS" | grep -E '\|refactor(\(.+\))?:' || echo "")

if [[ -z "$INCLUDED" && -z "$REVIEW" ]]; then
  echo "ERROR=All recent commits are internal/automated. Nothing to add to the changelog."
  exit 0
fi

# ── 7. Calculate version bump ────────────────────────────────────────────────

BUMP="patch"
if [[ -n "$INCLUDED" ]]; then
  if echo "$INCLUDED" | grep -qE '(BREAKING CHANGE|!\()'; then
    BUMP="major"
  elif echo "$INCLUDED" | grep -qE '\|(feat|style|ui|design)(\(.+\))?!?:'; then
    BUMP="minor"
  fi
fi

IFS='.' read -r MAJ MIN PAT <<< "$LAST_VERSION"
case "$BUMP" in
  major) NEW_VERSION="$((MAJ + 1)).0.0" ;;
  minor) NEW_VERSION="${MAJ}.$((MIN + 1)).0" ;;
  patch) NEW_VERSION="${MAJ}.${MIN}.$((PAT + 1))" ;;
esac

# ── 8. Determine INSERT vs UPDATE ────────────────────────────────────────────

TODAY=$(date +%Y-%m-%d)
if [[ "$LAST_DATE" == "$TODAY" ]]; then
  MODE="UPDATE"
else
  MODE="INSERT"
fi

# ── 9. Output structured manifest ────────────────────────────────────────────

echo "CHANGELOG_FILE=${CHANGELOG}"
echo "MODE=${MODE}"
echo "LAST_VERSION=${LAST_VERSION}"
echo "NEW_VERSION=${NEW_VERSION}"
echo "BUMP=${BUMP}"
echo "TODAY=${TODAY}"
echo "LAST_DATE=${LAST_DATE}"
echo "BOUNDARY_SHA=${BOUNDARY_SHA}"
echo "PREVIEW=${PREVIEW}"
echo "===INCLUDED==="
if [[ -n "$INCLUDED" ]]; then
  echo "$INCLUDED"
fi
echo "===REVIEW==="
if [[ -n "$REVIEW" ]]; then
  echo "$REVIEW"
fi
echo "===END==="
