#!/bin/bash

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DB_PATH="${DB_PATH:-$CODEX_HOME/logs_2.sqlite}"
TRIGGER_NAME="codex_suppress_trace_logs"
TABLE_NAME="logs"
SQLITE_TIMEOUT_MS="${SQLITE_TIMEOUT_MS:-5000}"

set -Eeuo pipefail

CURRENT_STEP="initializing"
START_TIME="$(date +%s)"
NORMALIZED_ACTION=""

log() {
  local level="$1"
  local message="$2"

  printf '[%s] %s\n' "$level" "$message"
}

usage() {
  cat <<EOF
Usage:
  $0 [enable|disable|status]

Without an action, the script opens a macOS selection popup when available.

Environment:
  TRACE_SUPPRESSION_ACTION
                          Optional action: enable, disable, or status.
  DB_PATH                 SQLite database path. Default: $DB_PATH
  CODEX_HOME              Codex home directory. Default: $CODEX_HOME
  SQLITE_TIMEOUT_MS       SQLite busy timeout. Default: $SQLITE_TIMEOUT_MS
  TRACE_SUPPRESSION_NO_POPUP=1
                          Disable macOS popup and require an action argument.
EOF
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

sqlite_scalar() {
  sqlite3 -cmd ".timeout ${SQLITE_TIMEOUT_MS}" "$DB_PATH" "$1"
}

finish() {
  local end_time
  local duration

  end_time="$(date +%s)"
  duration="$((end_time - START_TIME))"
  log "END" "Duration: ${duration}s"
}

select_action_with_popup() {
  local choice

  if [ "${TRACE_SUPPRESSION_NO_POPUP:-0}" = "1" ]; then
    return 1
  fi

  if ! command -v osascript >/dev/null 2>&1; then
    return 1
  fi

  if ! choice="$(osascript <<'APPLESCRIPT'
set choicesList to {"Enable TRACE suppression", "Disable TRACE suppression"}
set selectedItem to choose from list choicesList with title "Codex TRACE Log Suppression" with prompt "Choose an action:" OK button name "Run" cancel button name "Cancel"
if selectedItem is false then
  return "cancel"
else
  return item 1 of selectedItem
end if
APPLESCRIPT
)"; then
    return 1
  fi

  case "$choice" in
    "Enable TRACE suppression")
      printf 'enable\n'
      ;;
    "Disable TRACE suppression")
      printf 'disable\n'
      ;;
    "cancel")
      printf 'cancel\n'
      ;;
    *)
      return 1
      ;;
  esac
}

select_action_from_terminal() {
  local reply

  if [ ! -t 0 ]; then
    return 1
  fi

  printf 'Choose action:\n' >&2
  printf '  1) Enable TRACE suppression\n' >&2
  printf '  2) Disable TRACE suppression\n' >&2
  printf 'Selection [1/2]: ' >&2
  read -r reply

  case "$reply" in
    1|enable|on)
      printf 'enable\n'
      ;;
    2|disable|off)
      printf 'disable\n'
      ;;
    *)
      return 1
      ;;
  esac
}

normalize_action() {
  local raw_action="$1"

  case "$raw_action" in
    ""|prompt|choose|select)
      if NORMALIZED_ACTION="$(select_action_with_popup)"; then
        return 0
      fi

      if NORMALIZED_ACTION="$(select_action_from_terminal)"; then
        return 0
      fi

      error_exit "No action supplied and no interactive selector is available. Use: $0 enable|disable|status"
      ;;
    enable|on|install)
      NORMALIZED_ACTION="enable"
      ;;
    disable|off|remove)
      NORMALIZED_ACTION="disable"
      ;;
    status)
      NORMALIZED_ACTION="status"
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      error_exit "Unknown action: $raw_action. Use: $0 enable|disable|status"
      ;;
  esac
}

check_database() {
  CURRENT_STEP="checking database file"
  if [ ! -f "$DB_PATH" ]; then
    error_exit "Database file not found: $DB_PATH"
  fi
  log "OK" "Database file exists"
}

check_logs_schema() {
  local logs_table_count
  local level_column_count

  CURRENT_STEP="checking logs table"
  logs_table_count="$(sqlite_scalar "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = '$TABLE_NAME';")"
  if [ "$logs_table_count" != "1" ]; then
    error_exit "Required table not found: $TABLE_NAME"
  fi

  level_column_count="$(sqlite_scalar "SELECT count(*) FROM pragma_table_info('$TABLE_NAME') WHERE name = 'level';")"
  if [ "$level_column_count" != "1" ]; then
    error_exit "Required column not found: ${TABLE_NAME}.level"
  fi
  log "OK" "Database schema looks compatible"
}

trigger_count() {
  sqlite_scalar "SELECT count(*) FROM sqlite_master WHERE type = 'trigger' AND name = '$TRIGGER_NAME';"
}

enable_suppression() {
  local existing_trigger_count
  local created_trigger_count

  check_logs_schema

  CURRENT_STEP="checking existing trigger"
  existing_trigger_count="$(trigger_count)"
  if [ "$existing_trigger_count" = "1" ]; then
    log "NO_CHANGES" "TRACE suppression trigger already exists"
    return 0
  fi

  CURRENT_STEP="creating trace suppression trigger"
  sqlite3 "$DB_PATH" <<SQL
.timeout ${SQLITE_TIMEOUT_MS}
CREATE TRIGGER ${TRIGGER_NAME}
BEFORE INSERT ON ${TABLE_NAME}
WHEN NEW.level = 'TRACE'
BEGIN
  SELECT RAISE(IGNORE);
END;
SQL
  log "OK" "TRACE suppression trigger created"

  CURRENT_STEP="verifying trigger"
  created_trigger_count="$(trigger_count)"
  if [ "$created_trigger_count" != "1" ]; then
    error_exit "Trigger verification failed: $TRIGGER_NAME"
  fi
  log "SUCCESS" "TRACE logs will be ignored before they are inserted"
}

disable_suppression() {
  local existing_trigger_count
  local remaining_trigger_count

  CURRENT_STEP="checking existing trigger"
  existing_trigger_count="$(trigger_count)"
  if [ "$existing_trigger_count" = "0" ]; then
    log "NO_CHANGES" "TRACE suppression trigger is not installed"
    return 0
  fi

  CURRENT_STEP="dropping trace suppression trigger"
  sqlite3 "$DB_PATH" <<SQL
.timeout ${SQLITE_TIMEOUT_MS}
DROP TRIGGER IF EXISTS ${TRIGGER_NAME};
SQL
  log "OK" "TRACE suppression trigger dropped"

  CURRENT_STEP="verifying trigger removal"
  remaining_trigger_count="$(trigger_count)"
  if [ "$remaining_trigger_count" != "0" ]; then
    error_exit "Trigger removal verification failed: $TRIGGER_NAME"
  fi
  log "SUCCESS" "TRACE logs will be inserted normally again"
}

show_status() {
  local existing_trigger_count

  CURRENT_STEP="checking existing trigger"
  existing_trigger_count="$(trigger_count)"
  if [ "$existing_trigger_count" = "1" ]; then
    log "OK" "TRACE suppression trigger is installed"
  else
    log "OK" "TRACE suppression trigger is not installed"
  fi
}

main() {
  local action
  local raw_action

  trap 'on_error $? $LINENO' ERR

  if [ "$#" -gt 1 ]; then
    usage
    error_exit "Too many arguments"
  fi

  case "${1:-}" in
    -h|--help|help)
      usage
      exit 0
      ;;
  esac

  log "START" "Codex TRACE log suppression at $(date '+%Y-%m-%d %H:%M:%S')"

  CURRENT_STEP="selecting action"
  raw_action="${1:-${TRACE_SUPPRESSION_ACTION:-prompt}}"
  normalize_action "$raw_action"
  action="$NORMALIZED_ACTION"
  if [ "$action" = "cancel" ]; then
    log "NO_CHANGES" "Action cancelled"
    finish
    exit 0
  fi
  log "INFO" "Action: $action"
  log "INFO" "Database: $DB_PATH"
  log "INFO" "Trigger: $TRIGGER_NAME"

  CURRENT_STEP="checking dependencies"
  require_command sqlite3
  log "OK" "Dependencies available"

  check_database

  case "$action" in
    enable)
      enable_suppression
      ;;
    disable)
      disable_suppression
      ;;
    status)
      show_status
      ;;
  esac

  finish
}

main "$@"
