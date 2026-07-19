#!/bin/bash

LULU_APP="/Applications/LuLu.app"
CONFIG_DIR="/Library/Objective-See/LuLu"
PROCESS_NAME="LuLu"
EXTENSION_PROCESS_NAME="com.objective-see.lulu.extension"
WAIT_SECONDS="30"
SETUP_WAIT_SECONDS="240"
FILTER_TOGGLE_DELAY_SECONDS="3"
STATUS_MENU_BAR_INDEX="2"
STATUS_MENU_ITEM_INDEX="1"
TOGGLE_MENU_ITEM_INDEX="4"

set -Eeuo pipefail

CURRENT_STEP="initializing"
START_TIME="$(date +%s)"

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

  log "FAIL" "Step failed: ${CURRENT_STEP} (line ${line_no}, exit ${exit_code})" >&2
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

wait_for_process_state() {
  local process_name="$1"
  local expected_state="$2"
  local elapsed="0"

  while [ "$elapsed" -lt "$WAIT_SECONDS" ]; do
    if pgrep -x "$process_name" >/dev/null 2>&1; then
      if [ "$expected_state" = "running" ]; then
        return 0
      fi
    elif [ "$expected_state" = "stopped" ]; then
      return 0
    fi

    sleep 1
    elapsed="$((elapsed + 1))"
  done

  return 1
}

wait_for_first_run_setup() {
  local elapsed="0"

  while [ "$elapsed" -lt "$SETUP_WAIT_SECONDS" ]; do
    if plutil -extract installTime raw "${CONFIG_DIR}/preferences.plist" >/dev/null 2>&1; then
      return 0
    fi

    sleep 1
    elapsed="$((elapsed + 1))"
  done

  return 1
}

wait_for_disabled_state() {
  local expected_state="$1"
  local elapsed="0"
  local actual_state

  while [ "$elapsed" -lt "$WAIT_SECONDS" ]; do
    actual_state="$(plutil -extract disabled raw "${CONFIG_DIR}/preferences.plist" 2>/dev/null || true)"
    if [ "$actual_state" = "$expected_state" ]; then
      return 0
    fi

    sleep 1
    elapsed="$((elapsed + 1))"
  done

  return 1
}

wait_for_disabled_state_available() {
  local elapsed="0"
  local actual_state

  while [ "$elapsed" -lt "$WAIT_SECONDS" ]; do
    actual_state="$(plutil -extract disabled raw "${CONFIG_DIR}/preferences.plist" 2>/dev/null || true)"
    if [ "$actual_state" = "false" ] || [ "$actual_state" = "true" ]; then
      return 0
    fi

    sleep 1
    elapsed="$((elapsed + 1))"
  done

  return 1
}

click_lulu_filter_toggle() {
  osascript - "$STATUS_MENU_BAR_INDEX" "$STATUS_MENU_ITEM_INDEX" "$TOGGLE_MENU_ITEM_INDEX" <<'APPLESCRIPT'
on run arguments
  set menuBarIndex to item 1 of arguments as integer
  set statusItemIndex to item 2 of arguments as integer
  set toggleItemIndex to item 3 of arguments as integer

  tell application "System Events" to tell process "LuLu"
    click menu bar item statusItemIndex of menu bar menuBarIndex
    delay 0.3
    set toggleTitle to name of menu item toggleItemIndex of menu 1 of menu bar item statusItemIndex of menu bar menuBarIndex
    click menu item toggleItemIndex of menu 1 of menu bar item statusItemIndex of menu bar menuBarIndex
  end tell

  return toggleTitle
end run
APPLESCRIPT
}

trap 'on_error $? $LINENO' ERR

log "START" "LuLu configuration reset started at $(date '+%Y-%m-%d %H:%M:%S')"

CURRENT_STEP="checking platform and dependencies"
if [ "$(uname -s)" != "Darwin" ]; then
  error_exit "This script is intended for macOS"
fi

for command_name in killall open osascript pgrep plutil sleep sudo; do
  require_command "$command_name"
done

LULU_BINARY="${LULU_APP}/Contents/MacOS/LuLu"
if [ ! -x "$LULU_BINARY" ]; then
  error_exit "LuLu executable not found: $LULU_BINARY"
fi

if [ "$CONFIG_DIR" != "/Library/Objective-See/LuLu" ]; then
  error_exit "Refusing unexpected configuration directory: $CONFIG_DIR"
fi
log "OK" "Platform, dependencies, and paths verified"

CURRENT_STEP="checking accessibility permission"
accessibility_status=""
if ! accessibility_status="$(osascript -e 'tell application "System Events" to get UI elements enabled')"; then
  error_exit "Accessibility permission is required for TaskTick to control LuLu"
fi
if [ "$accessibility_status" != "true" ]; then
  error_exit "Enable TaskTick in System Settings > Privacy & Security > Accessibility"
fi
log "OK" "Accessibility permission ready"

CURRENT_STEP="closing LuLu"
log "INFO" "Closing the LuLu app while preserving system extension approval"
if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
  killall -KILL "$PROCESS_NAME"
else
  log "NO_CHANGES" "LuLu app was not running"
fi

if ! wait_for_process_state "$PROCESS_NAME" "stopped"; then
  error_exit "LuLu is still running after ${WAIT_SECONDS}s"
fi
log "OK" "LuLu closed"

CURRENT_STEP="preparing administrator permission"
if [ "$(id -u)" -ne 0 ]; then
  log "INFO" "Administrator permission is required to delete LuLu configuration"
  sudo -v
fi
log "OK" "Administrator permission ready"

CURRENT_STEP="deleting LuLu configuration"
config_found="0"
for config_path in \
  "${CONFIG_DIR}/preferences.plist" \
  "${CONFIG_DIR}/rules.plist" \
  "${CONFIG_DIR}/rules_v1.plist" \
  "${CONFIG_DIR}/Profiles"; do
  if [ -e "$config_path" ]; then
    config_found="1"
    sudo /bin/rm -rf "$config_path"
    log "OK" "Deleted: $config_path"
  fi
done

if [ "$config_found" = "0" ]; then
  log "NO_CHANGES" "No LuLu configuration files were present"
fi

for config_path in \
  "${CONFIG_DIR}/preferences.plist" \
  "${CONFIG_DIR}/rules.plist" \
  "${CONFIG_DIR}/rules_v1.plist" \
  "${CONFIG_DIR}/Profiles"; do
  if [ -e "$config_path" ]; then
    error_exit "Configuration path still exists: $config_path"
  fi
done
log "OK" "LuLu configuration deletion verified"

CURRENT_STEP="reopening LuLu"
open "$LULU_APP"
if ! wait_for_process_state "$PROCESS_NAME" "running"; then
  error_exit "LuLu did not reopen within ${WAIT_SECONDS}s"
fi
log "OK" "LuLu reopened"

CURRENT_STEP="waiting for LuLu first-run setup"
log "INFO" "Finish the LuLu first-run setup within ${SETUP_WAIT_SECONDS}s"
if ! wait_for_first_run_setup; then
  error_exit "LuLu first-run setup was not completed within ${SETUP_WAIT_SECONDS}s"
fi
log "OK" "LuLu first-run setup completed"

CURRENT_STEP="resetting LuLu network filter"
if ! wait_for_disabled_state_available; then
  error_exit "LuLu did not publish its enabled state"
fi

disabled_state="$(plutil -extract disabled raw "${CONFIG_DIR}/preferences.plist")"
if [ "$disabled_state" = "false" ]; then
  toggle_title="$(click_lulu_filter_toggle)"
  log "INFO" "LuLu menu action: $toggle_title"
  if ! wait_for_disabled_state "true"; then
    error_exit "LuLu did not enter the disabled state"
  fi
  sleep "$FILTER_TOGGLE_DELAY_SECONDS"
fi

toggle_title="$(click_lulu_filter_toggle)"
log "INFO" "LuLu menu action: $toggle_title"
if ! wait_for_disabled_state "false"; then
  error_exit "LuLu did not return to the enabled state"
fi
sleep "$FILTER_TOGGLE_DELAY_SECONDS"

if ! wait_for_process_state "$EXTENSION_PROCESS_NAME" "running"; then
  error_exit "LuLu monitoring extension is not running"
fi
log "OK" "LuLu network filter is enabled and its extension is running"

log "SUCCESS" "LuLu configuration reset completed and monitoring restored"
finish
