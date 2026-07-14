#!/bin/bash

NETWORKSETUP_BIN="${NETWORKSETUP_BIN:-/usr/sbin/networksetup}"
OSASCRIPT_BIN="${OSASCRIPT_BIN:-/usr/bin/osascript}"
SUDO_BIN="${SUDO_BIN:-/usr/bin/sudo}"
VERIFY_RETRIES="${VERIFY_RETRIES:-3}"

set -u

SUDO_CMD=()

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
IPv6 for every available macOS network service. Changing network settings
uses sudo authentication, including Touch ID when enabled for sudo.
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

run_networksetup() {
  "${SUDO_CMD[@]}" "$NETWORKSETUP_BIN" "$@"
}

select_action() {
  "$OSASCRIPT_BIN" <<'APPLESCRIPT'
tell application "Finder"
    activate
    set selectedItem to choose from list {"开启 IPv6", "关闭 IPv6"} ¬
        with title "IPv6 设置" ¬
        with prompt "此操作将应用到所有可用网络服务：" ¬
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
    enable|on|"开启 IPv6")
      printf 'enable\n'
      ;;
    disable|off|"关闭 IPv6")
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

trim_whitespace() {
  local value="$1"

  while [ "${value# }" != "$value" ]; do
    value="${value# }"
  done
  while [ "${value#$'\t'}" != "$value" ]; do
    value="${value#$'\t'}"
  done
  while [ "${value% }" != "$value" ]; do
    value="${value% }"
  done
  while [ "${value%$'\t'}" != "$value" ]; do
    value="${value%$'\t'}"
  done

  printf '%s\n' "$value"
}

normalize_service() {
  local service="$1"

  service="${service%$'\r'}"

  case "$service" in
    "An asterisk ("*)
      return 1
      ;;
  esac

  case "$service" in
    \*)
      service="${service#\*}"
      ;;
  esac

  service="$(trim_whitespace "$service")"

  if [ -z "$service" ]; then
    return 1
  fi

  printf '%s\n' "$service"
}

list_network_services() {
  local output

  if ! output="$(run_networksetup -listallnetworkservices 2>&1)"; then
    error_exit "Unable to list network services: $output"
  fi

  case "$output" in
    *"AuthorizationCreate() failed"*)
      error_exit "Unable to access macOS network authorization services: $output"
      ;;
  esac

  printf '%s\n' "$output"
}

read_ipv6_status() {
  local service="$1"
  local info
  local line
  local status

  if ! info="$(run_networksetup -getinfo "$service" 2>&1)"; then
    return 1
  fi

  while IFS= read -r line; do
    line="${line%$'\r'}"

    case "$line" in
      IPv6:*)
        status="${line#IPv6:}"
        status="$(trim_whitespace "$status")"

        if [ -n "$status" ]; then
          printf '%s\n' "$status"
          return 0
        fi
        ;;
    esac
  done <<< "$info"

  return 2
}

verify_service() {
  local service="$1"
  local expected="$2"
  local attempt=1
  local status
  local read_code

  while [ "$attempt" -le "$VERIFY_RETRIES" ]; do
    status="$(read_ipv6_status "$service")"
    read_code=$?

    if [ "$read_code" -ne 0 ]; then
      return 2
    fi

    if [ "$status" = "$expected" ]; then
      return 0
    fi

    if [ "$attempt" -lt "$VERIFY_RETRIES" ]; then
      sleep 1
    fi

    attempt=$((attempt + 1))
  done

  return 1
}

apply_to_all_services() {
  local action="$1"
  local command_option
  local expected_status
  local action_label
  local services
  local raw_service
  local service
  local previous_status
  local current_status
  local output
  local verify_code
  local service_count=0
  local success_count=0
  local skipped_count=0
  local failure_count=0

  case "$action" in
    enable)
      command_option="-setv6automatic"
      expected_status="Automatic"
      action_label="Enable IPv6"
      ;;
    disable)
      command_option="-setv6off"
      expected_status="Off"
      action_label="Disable IPv6"
      ;;
    *)
      error_exit "Invalid privileged action: $action"
      ;;
  esac

  services="$(list_network_services)"
  log "START" "$action_label for all network services"

  while IFS= read -r raw_service; do
    if ! service="$(normalize_service "$raw_service")"; then
      continue
    fi

    service_count=$((service_count + 1))
    log "INFO" "Checking network service: $service"

    if ! previous_status="$(read_ipv6_status "$service")"; then
      log "INFO" "Skipping unavailable or IPv6-incompatible service: $service"
      skipped_count=$((skipped_count + 1))
      continue
    fi

    if [ "$previous_status" = "$expected_status" ]; then
      log "NO_CHANGES" "$service already reports IPv6 $expected_status"
      success_count=$((success_count + 1))
      continue
    fi

    log "START" "$action_label: $service"

    if ! output="$(run_networksetup "$command_option" "$service" 2>&1)"; then
      if current_status="$(read_ipv6_status "$service")"; then
        if [ "$current_status" = "$expected_status" ]; then
          log "OK" "$service reports IPv6 $expected_status despite command output"
          success_count=$((success_count + 1))
          continue
        fi

        log "FAIL" "$action_label failed for $service: $output" >&2
        log "FAIL" "$service still reports IPv6 $current_status" >&2
        failure_count=$((failure_count + 1))
      else
        log "INFO" "Skipping service that became unavailable: $service"
        skipped_count=$((skipped_count + 1))
      fi

      continue
    fi

    verify_service "$service" "$expected_status"
    verify_code=$?

    case "$verify_code" in
      0)
        log "OK" "$service: IPv6 $expected_status"
        success_count=$((success_count + 1))
        ;;
      1)
        current_status="$(read_ipv6_status "$service" 2>/dev/null || printf 'Unknown')"
        log "FAIL" "$service reports IPv6 $current_status; expected $expected_status" >&2
        failure_count=$((failure_count + 1))
        ;;
      2)
        log "INFO" "Skipping service that cannot be verified: $service"
        skipped_count=$((skipped_count + 1))
        ;;
    esac
  done <<< "$services"

  if [ "$service_count" -eq 0 ]; then
    error_exit "No network services found"
  fi

  log "INFO" "Processed: $service_count, successful: $success_count, skipped: $skipped_count, failed: $failure_count"

  if [ "$failure_count" -ne 0 ]; then
    log "FAIL" "$failure_count available network service(s) did not reach the requested IPv6 state" >&2
    exit 1
  fi

  if [ "$success_count" -eq 0 ]; then
    error_exit "No available network service could be configured"
  fi

  log "SUCCESS" "$action_label completed"
  log "END" "IPv6 operation completed"
}

run_with_sudo() {
  local action="$1"
  local privileged_script

  if [ "$(id -u)" -eq 0 ]; then
    SUDO_CMD=()
    apply_to_all_services "$action"
    return
  fi

  privileged_script="$(declare -f \
    log \
    error_exit \
    run_networksetup \
    trim_whitespace \
    normalize_service \
    list_network_services \
    read_ipv6_status \
    verify_service \
    apply_to_all_services)"
  privileged_script="$privileged_script"$'\nNETWORKSETUP_BIN="$2"\nVERIFY_RETRIES="$3"\nSUDO_CMD=()\napply_to_all_services "$1"\n'

  log "INFO" "Touch ID or administrator authentication is required once"
  "$SUDO_BIN" /bin/bash -c "$privileged_script" \
    ipv6-helper "$action" "$NETWORKSETUP_BIN" "$VERIFY_RETRIES"
}

main() {
  local raw_action
  local action

  require_executable "$NETWORKSETUP_BIN"
  require_executable "$OSASCRIPT_BIN"
  require_executable "$SUDO_BIN"

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

  if [ "$#" -eq 1 ]; then
    raw_action="$1"
  elif ! raw_action="$(select_action)"; then
    error_exit "Unable to open the IPv6 action dialog"
  fi

  if ! action="$(normalize_action "$raw_action")"; then
    usage
    error_exit "Unknown action: $raw_action"
  fi

  if [ "$action" = "cancel" ]; then
    log "NO_CHANGES" "Action cancelled"
    log "END" "No IPv6 settings were changed"
    exit 0
  fi

  log "INFO" "Action: $action"
  run_with_sudo "$action"
}

main "$@"
