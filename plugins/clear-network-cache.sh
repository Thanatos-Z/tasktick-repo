#!/bin/bash

REQUIRE_MACOS="1"
PING_HOST="${PING_HOST:-apple.com}"

set -Eeuo pipefail

CURRENT_STEP="initializing"
START_TIME="$(date +%s)"
DRY_RUN="0"
CHECK_CONNECTIVITY="0"
SUDO_CMD=()

log() {
  local level="$1"
  local message="$2"

  printf '[%s] %s\n' "$level" "$message"
}

finish() {
  local end_time
  local duration

  end_time="$(date +%s)"
  duration="$((end_time - START_TIME))"
  log "END" "Duration: ${duration}s"
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

usage() {
  cat <<'USAGE'
Usage: clear-network-cache.sh [--dry-run] [--check-connectivity] [--help]

Clears macOS DNS and local name-resolution caches.

Options:
  --dry-run             Show what would run without changing anything.
  --check-connectivity  Ping PING_HOST after clearing caches. Default: apple.com.
  --help                Show this help.

Environment:
  PING_HOST             Host used by --check-connectivity.
USAGE
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error_exit "Missing required command: $1"
  fi
}

run_command() {
  if [ "$DRY_RUN" = "1" ]; then
    log "INFO" "Dry run: $*"
    return 0
  fi

  "$@"
}

run_privileged() {
  if [ "$DRY_RUN" = "1" ]; then
    if [ "${#SUDO_CMD[@]}" -gt 0 ]; then
      log "INFO" "Dry run: ${SUDO_CMD[*]} $*"
    else
      log "INFO" "Dry run: $*"
    fi
    return 0
  fi

  "${SUDO_CMD[@]}" "$@"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        DRY_RUN="1"
        ;;
      --check-connectivity)
        CHECK_CONNECTIVITY="1"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        error_exit "Unknown argument: $1"
        ;;
    esac
    shift
  done
}

prepare_privileges() {
  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi

  if [ "$(id -u)" = "0" ]; then
    SUDO_CMD=()
    return 0
  fi

  require_command sudo
  log "INFO" "Administrator permission is required to signal mDNSResponder"
  sudo -v
  SUDO_CMD=(sudo)
}

clear_dns_cache() {
  CURRENT_STEP="flushing directory service cache"
  run_command dscacheutil -flushcache
  log "OK" "Directory service cache flushed"

  CURRENT_STEP="signaling mDNSResponder"
  run_privileged killall -HUP mDNSResponder
  log "OK" "mDNSResponder cache refresh requested"
}

check_connectivity() {
  if [ "$CHECK_CONNECTIVITY" != "1" ]; then
    return 0
  fi

  CURRENT_STEP="checking connectivity"
  if [ "$DRY_RUN" = "1" ]; then
    run_command ping -c 1 -W 3000 "$PING_HOST"
    log "OK" "Connectivity check skipped in dry run"
    return 0
  fi

  if run_command ping -c 1 -W 3000 "$PING_HOST" >/dev/null; then
    log "OK" "Connectivity check passed: $PING_HOST"
  else
    error_exit "Connectivity check failed: $PING_HOST"
  fi
}

trap 'on_error $? $LINENO' ERR

parse_args "$@"

log "START" "Network cache cleanup started at $(date '+%Y-%m-%d %H:%M:%S')"
log "INFO" "Ping host: $PING_HOST"

CURRENT_STEP="checking platform"
if [ "$REQUIRE_MACOS" = "1" ] && [ "$(uname -s)" != "Darwin" ]; then
  error_exit "This script is intended for macOS"
fi
log "OK" "Platform looks compatible"

CURRENT_STEP="checking dependencies"
require_command dscacheutil
require_command killall
require_command id
if [ "$CHECK_CONNECTIVITY" = "1" ]; then
  require_command ping
fi
log "OK" "Dependencies available"

CURRENT_STEP="preparing privileges"
prepare_privileges
log "OK" "Privileges ready"

clear_dns_cache
check_connectivity

log "SUCCESS" "Network cache cleanup completed"
finish
