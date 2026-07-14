#!/bin/bash

VPN_SERVICE="${VPN_SERVICE:-Shadowrocket}"
SCUTIL_BIN="${SCUTIL_BIN:-/usr/sbin/scutil}"
OSASCRIPT_BIN="${OSASCRIPT_BIN:-/usr/bin/osascript}"
STATUS_TIMEOUT_SECONDS="${STATUS_TIMEOUT_SECONDS:-15}"

set -u

log() {
  local level="$1"
  local message="$2"

  printf '[%s] %s\n' "$level" "$message"
}

usage() {
  cat <<EOF
Usage:
  $0 [enable|disable]

Without an action, a Finder-hosted macOS dialog lets you enable or disable
the Shadowrocket VPN connection.

Environment:
  VPN_SERVICE             VPN service name. Default: $VPN_SERVICE
  STATUS_TIMEOUT_SECONDS  Connection state timeout. Default: $STATUS_TIMEOUT_SECONDS
EOF
}

error_exit() {
  log "FAIL" "$1" >&2
  exit 1
}

require_executable() {
  if [ ! -x "$1" ]; then
    error_exit "Missing required executable: $1"
  fi
}

select_action() {
  "$OSASCRIPT_BIN" <<'APPLESCRIPT'
tell application "Finder"
    activate
    set selectedItem to choose from list {"开启 VPN", "关闭 VPN"} ¬
        with title "Shadowrocket VPN" ¬
        with prompt "请选择操作：" ¬
        OK button name "执行" ¬
        cancel button name "取消"
end tell

if selectedItem is false then
    return "cancel"
else
    return item 1 of selectedItem
end if
APPLESCRIPT
}

normalize_action() {
  case "$1" in
    enable|start|on|"开启 VPN")
      printf 'enable\n'
      ;;
    disable|stop|off|"关闭 VPN")
      printf 'disable\n'
      ;;
    cancel)
      printf 'cancel\n'
      ;;
    *)
      return 1
      ;;
  esac
}

check_service() {
  local services

  if ! services="$("$SCUTIL_BIN" --nc list 2>&1)"; then
    error_exit "Unable to list VPN services: $services"
  fi

  case "$services" in
    *\"$VPN_SERVICE\"*)
      log "OK" "VPN service found: $VPN_SERVICE"
      ;;
    *)
      error_exit "VPN service not found: $VPN_SERVICE"
      ;;
  esac
}

current_status() {
  local output

  if ! output="$("$SCUTIL_BIN" --nc status "$VPN_SERVICE" 2>&1)"; then
    return 1
  fi

  printf '%s\n' "${output%%$'\n'*}"
}

wait_for_status() {
  local expected_status="$1"
  local elapsed=0
  local status

  while [ "$elapsed" -lt "$STATUS_TIMEOUT_SECONDS" ]; do
    status="$(current_status)" || return 1
    if [ "$status" = "$expected_status" ]; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

enable_vpn() {
  local status
  local output

  status="$(current_status)" || error_exit "Unable to read VPN status"
  if [ "$status" = "Connected" ]; then
    log "NO_CHANGES" "Shadowrocket VPN is already connected"
    return 0
  fi

  log "START" "Connecting Shadowrocket VPN"
  if ! output="$("$SCUTIL_BIN" --nc start "$VPN_SERVICE" 2>&1)"; then
    error_exit "Unable to start Shadowrocket VPN: $output"
  fi

  if ! wait_for_status "Connected"; then
    status="$(current_status 2>/dev/null || printf 'Unknown')"
    error_exit "VPN did not connect within ${STATUS_TIMEOUT_SECONDS}s (status: $status)"
  fi

  log "SUCCESS" "Shadowrocket VPN connected"
}

disable_vpn() {
  local status
  local output

  status="$(current_status)" || error_exit "Unable to read VPN status"
  if [ "$status" = "Disconnected" ]; then
    log "NO_CHANGES" "Shadowrocket VPN is already disconnected"
    return 0
  fi

  log "START" "Disconnecting Shadowrocket VPN"
  if ! output="$("$SCUTIL_BIN" --nc stop "$VPN_SERVICE" 2>&1)"; then
    error_exit "Unable to stop Shadowrocket VPN: $output"
  fi

  if ! wait_for_status "Disconnected"; then
    status="$(current_status 2>/dev/null || printf 'Unknown')"
    error_exit "VPN did not disconnect within ${STATUS_TIMEOUT_SECONDS}s (status: $status)"
  fi

  log "SUCCESS" "Shadowrocket VPN disconnected"
}

main() {
  local raw_action
  local action

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

  require_executable "$SCUTIL_BIN"
  require_executable "$OSASCRIPT_BIN"
  check_service

  if [ "$#" -eq 1 ]; then
    raw_action="$1"
  else
    if ! raw_action="$(select_action)"; then
      error_exit "Unable to open the action selection dialog"
    fi
  fi

  if ! action="$(normalize_action "$raw_action")"; then
    usage
    error_exit "Unknown action: $raw_action"
  fi

  if [ "$action" = "cancel" ]; then
    log "NO_CHANGES" "Action cancelled"
    log "END" "No VPN changes were made"
    exit 0
  fi

  log "INFO" "Action: $action"
  case "$action" in
    enable)
      enable_vpn
      ;;
    disable)
      disable_vpn
      ;;
  esac
  log "END" "Shadowrocket VPN action completed"
}

main "$@"
