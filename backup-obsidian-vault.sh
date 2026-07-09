#!/bin/bash

VAULT="/Users/youzhi/Library/Mobile Documents/iCloud~md~obsidian/Documents/youzhi"
REPO="https://github.com/Thanatos-Z/my-obsidian.git"
BRANCH="main"

set -Eeuo pipefail

TMP_DIR=""
WORKTREE=""
CURRENT_STEP="initializing"
START_TIME="$(date +%s)"

log() {
  local level="$1"
  local message="$2"

  printf '[%s] %s\n' "$level" "$message"
}

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
    log "CLEANUP" "Removed temporary directory"
  fi
}

on_error() {
  local exit_code="$1"
  local line_no="$2"

  log "FAIL" "Step failed: ${CURRENT_STEP} (line ${line_no}, exit ${exit_code})"
  exit "$exit_code"
}

error_exit() {
  log "FAIL" "$1" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error_exit "Missing required command: $1"
  fi
}

count_status() {
  local status_output="$1"
  local pattern="$2"

  printf '%s\n' "$status_output" | awk -v pat="$pattern" 'substr($0, 1, 2) ~ pat { count++ } END { print count + 0 }'
}

finish() {
  local end_time
  local duration

  end_time="$(date +%s)"
  duration="$((end_time - START_TIME))"
  log "END" "Duration: ${duration}s"
}

trap cleanup EXIT
trap 'on_error $? $LINENO' ERR

log "START" "Obsidian backup started at $(date '+%Y-%m-%d %H:%M:%S')"
log "INFO" "Vault: $VAULT"
log "INFO" "Repo: $REPO"
log "INFO" "Branch: $BRANCH"

CURRENT_STEP="checking dependencies"
require_command git
require_command rsync
require_command mktemp
require_command awk
log "OK" "Dependencies available"

CURRENT_STEP="checking vault directory"
if [ ! -d "$VAULT" ]; then
  error_exit "Vault directory not found: $VAULT"
fi
log "OK" "Vault directory exists"

CURRENT_STEP="creating temporary directory"
TMP_DIR="$(mktemp -d)"
WORKTREE="$TMP_DIR/repo"
log "OK" "Temporary directory created"

CURRENT_STEP="cloning repository"
log "INFO" "Cloning repository"
git clone "$REPO" "$WORKTREE"
log "OK" "Repository cloned"

CURRENT_STEP="checking out branch"
cd "$WORKTREE"
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  git checkout -B "$BRANCH" "origin/$BRANCH"
  log "OK" "Checked out existing branch: $BRANCH"
else
  git checkout -B "$BRANCH"
  log "OK" "Created local branch: $BRANCH"
fi

CURRENT_STEP="syncing vault files"
log "INFO" "Syncing vault into temporary repository"
rsync -a --delete \
  --exclude='.git' \
  --exclude='.DS_Store' \
  --exclude='.Trash' \
  --exclude='.trash' \
  --exclude='.obsidian/workspace.json' \
  --exclude='.obsidian/workspace-mobile.json' \
  --exclude='.obsidian/cache/' \
  --exclude='*.tmp' \
  --exclude='*.swp' \
  "$VAULT"/ "$WORKTREE"/
log "OK" "Rsync completed"

CURRENT_STEP="cleaning excluded files from repository copy"
find "$WORKTREE" -path "$WORKTREE/.git" -prune -o -name '.DS_Store' -type f -exec rm -f {} +
find "$WORKTREE" -path "$WORKTREE/.git" -prune -o -name '*.tmp' -type f -exec rm -f {} +
find "$WORKTREE" -path "$WORKTREE/.git" -prune -o -name '*.swp' -type f -exec rm -f {} +
rm -rf "$WORKTREE/.Trash" "$WORKTREE/.trash" "$WORKTREE/.obsidian/cache"
rm -f "$WORKTREE/.obsidian/workspace.json" "$WORKTREE/.obsidian/workspace-mobile.json"
log "OK" "Excluded files cleaned from temporary copy"

CURRENT_STEP="checking changes"
STATUS_OUTPUT="$(git status --porcelain --untracked-files=all)"

if [ -z "$STATUS_OUTPUT" ]; then
  log "NO_CHANGES" "No changes"
  finish
  exit 0
fi

TOTAL_CHANGES="$(printf '%s\n' "$STATUS_OUTPUT" | sed '/^$/d' | wc -l | tr -d ' ')"
ADDED_CHANGES="$(count_status "$STATUS_OUTPUT" '(\?\?|A)')"
MODIFIED_CHANGES="$(count_status "$STATUS_OUTPUT" 'M')"
DELETED_CHANGES="$(count_status "$STATUS_OUTPUT" 'D')"
RENAMED_CHANGES="$(count_status "$STATUS_OUTPUT" 'R')"
OTHER_CHANGES="$((TOTAL_CHANGES - ADDED_CHANGES - MODIFIED_CHANGES - DELETED_CHANGES - RENAMED_CHANGES))"

log "INFO" "Changes detected: total=${TOTAL_CHANGES}, added=${ADDED_CHANGES}, modified=${MODIFIED_CHANGES}, deleted=${DELETED_CHANGES}, renamed=${RENAMED_CHANGES}, other=${OTHER_CHANGES}"

CURRENT_STEP="staging changes"
git add -A
log "OK" "Changes staged"

CURRENT_STEP="checking staged changes"
if git diff --cached --quiet -- .; then
  log "NO_CHANGES" "No staged changes after exclusions"
  finish
  exit 0
fi

CURRENT_STEP="committing changes"
COMMIT_MESSAGE="Update Obsidian notes $(date '+%Y-%m-%d %H')"
git commit -m "$COMMIT_MESSAGE"
COMMIT_SHA="$(git rev-parse --short HEAD)"
log "OK" "Committed: ${COMMIT_SHA}"
log "INFO" "Commit message: ${COMMIT_MESSAGE}"

CURRENT_STEP="pushing changes"
git push origin "$BRANCH"
log "SUCCESS" "Backup pushed to ${REPO} (${BRANCH})"
log "SUCCESS" "Updated files: total=${TOTAL_CHANGES}, added=${ADDED_CHANGES}, modified=${MODIFIED_CHANGES}, deleted=${DELETED_CHANGES}, renamed=${RENAMED_CHANGES}, other=${OTHER_CHANGES}"

finish
