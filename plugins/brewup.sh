#!/bin/bash

PROXY_URL="${PROXY_URL:-http://127.0.0.1:1082}"

set -u

FAILED_STEPS=()

log() {
  local level="$1"
  local message="$2"

  printf '[%s] %s\n' "$level" "$message"
}

usage() {
  cat <<EOF
Usage: $0

Update, upgrade, and clean Homebrew packages. A Finder-hosted macOS dialog
asks whether to enable the proxy before maintenance starts.

Environment:
  PROXY_URL    Proxy used when enabled. Default: $PROXY_URL
EOF
}

select_proxy_mode() {
  /usr/bin/osascript <<'APPLESCRIPT'
tell application "Finder"
    activate
    set selectedItem to choose from list {"开启代理", "不使用代理"} ¬
        with title "Homebrew 维护" ¬
        with prompt "是否开启代理？" ¬
        default items {"不使用代理"} ¬
        OK button name "继续" ¬
        cancel button name "取消"
end tell

if selectedItem is false then
    return "cancel"
else
    return item 1 of selectedItem
end if
APPLESCRIPT
}

confirm_updates() {
  /usr/bin/osascript - "$1" <<'APPLESCRIPT'
on run argv
    set outdatedItems to paragraphs of (item 1 of argv)

    tell application "Finder"
        activate
        set selectedItem to choose from list outdatedItems ¬
            with title "Homebrew 待更新项目" ¬
            with prompt ("共 " & (count of outdatedItems) & " 个待更新项目：") ¬
            default items {item 1 of outdatedItems} ¬
            OK button name "开始更新" ¬
            cancel button name "取消"
    end tell

    if selectedItem is false then
        return "cancel"
    else
        return "upgrade"
    end if
end run
APPLESCRIPT
}

show_no_updates() {
  /usr/bin/osascript <<'APPLESCRIPT'
tell application "Finder"
    activate
    display dialog "当前没有需要更新的软件。" ¬
        with title "Homebrew 维护" ¬
        buttons {"确定"} ¬
        default button "确定"
end tell
APPLESCRIPT
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "FAIL" "Missing required command: $1" >&2
    exit 1
  fi
}

run_step() {
  local name="$1"
  shift

  log "START" "$name"
  if "$@"; then
    log "OK" "$name completed"
  else
    local exit_code=$?
    log "FAIL" "$name failed (exit $exit_code)" >&2
    FAILED_STEPS+=("$name")
  fi
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    log "FAIL" "Unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
esac

require_command brew
require_command /usr/bin/osascript

export HOMEBREW_NO_ASK=1

if ! proxy_mode="$(select_proxy_mode)"; then
  log "FAIL" "Unable to open the proxy selection dialog" >&2
  exit 1
fi

case "$proxy_mode" in
  "开启代理")
    export http_proxy="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    log "INFO" "Proxy enabled: $PROXY_URL"
    ;;
  "不使用代理")
    log "INFO" "Proxy disabled"
    ;;
  cancel)
    log "END" "Cancelled before Homebrew maintenance started"
    exit 0
    ;;
  *)
    log "FAIL" "Unexpected proxy selection: $proxy_mode" >&2
    exit 1
    ;;
esac

log "START" "Homebrew maintenance started at $(date '+%Y-%m-%d %H:%M:%S')"

run_step "Update package sources" brew update

log "INFO" "Outdated packages:"
if outdated_packages="$(brew outdated --greedy)"; then
  :
else
  exit_code=$?
  log "FAIL" "Unable to retrieve outdated packages (exit $exit_code)" >&2
  exit "$exit_code"
fi

if [ -z "$outdated_packages" ]; then
  log "NO_CHANGES" "No outdated packages"
  if ! show_no_updates >/dev/null; then
    log "FAIL" "Unable to show the no-updates dialog" >&2
    exit 1
  fi
  log "INFO" "Skipping package upgrade and continuing maintenance"
else
  printf '%s\n' "$outdated_packages"

  if ! update_action="$(confirm_updates "$outdated_packages")"; then
    log "FAIL" "Unable to show the update confirmation dialog" >&2
    exit 1
  fi

  if [ "$update_action" = "cancel" ]; then
    log "NO_CHANGES" "Package upgrade cancelled"
    log "END" "Homebrew maintenance cancelled before upgrade"
    exit 0
  fi

  run_step "Upgrade packages" brew upgrade --greedy
fi

run_step "Remove unused dependencies" brew autoremove
run_step "Clean old versions and cache" brew cleanup

if (( ${#FAILED_STEPS[@]} == 0 )); then
  log "SUCCESS" "Homebrew maintenance completed"
  log "END" "All steps succeeded"
  exit 0
fi

log "FAIL" "Failed steps:" >&2
printf '  - %s\n' "${FAILED_STEPS[@]}" >&2
log "END" "Homebrew maintenance finished with ${#FAILED_STEPS[@]} failure(s)" >&2
exit 1
