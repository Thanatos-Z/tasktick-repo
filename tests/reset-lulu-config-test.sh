#!/bin/bash

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
FAKE_BIN="${TEST_DIR}/bin"
FAKE_APP="${TEST_DIR}/LuLu.app"
FAKE_CONFIG="${TEST_DIR}/config"
STATE_DIR="${TEST_DIR}/state"
UNDER_TEST="${TEST_DIR}/reset-lulu-config.sh"

cleanup() {
  /bin/rm -rf "$TEST_DIR"
}

trap cleanup EXIT

mkdir -p "$FAKE_BIN" "${FAKE_APP}/Contents/MacOS" "${FAKE_CONFIG}/Profiles" "$STATE_DIR"
printf 'old preferences\n' >"${FAKE_CONFIG}/preferences.plist"
printf 'old rules\n' >"${FAKE_CONFIG}/rules.plist"
printf 'running\n' >"${STATE_DIR}/gui"
printf 'enabled\n' >"${STATE_DIR}/extension"

sed \
  -e "s#/Applications/LuLu.app#${FAKE_APP}#g" \
  -e "s#/Library/Objective-See/LuLu#${FAKE_CONFIG}#g" \
  -e 's/WAIT_SECONDS="15"/WAIT_SECONDS="1"/' \
  "${PROJECT_DIR}/plugins/reset-lulu-config.sh" >"$UNDER_TEST"
chmod 755 "$UNDER_TEST"

printf '%s\n' \
  '#!/bin/bash' \
  'printf "%s\n" "$1" >>"'"${STATE_DIR}"'/commands"' \
  'if [ "$1" = "-quit" ]; then' \
  '  printf "stopped\n" >"'"${STATE_DIR}"'/gui"' \
  '  printf "disabled\n" >"'"${STATE_DIR}"'/extension"' \
  '  : >"'"${STATE_DIR}"'/activation_requires_user"' \
  '  exit 255' \
  'fi' \
  'exit 2' >"${FAKE_APP}/Contents/MacOS/LuLu"
chmod 755 "${FAKE_APP}/Contents/MacOS/LuLu"

printf '%s\n' \
  '#!/bin/bash' \
  'if [ "$1" = "-x" ] && [ "$2" = "LuLu" ]; then' \
  '  [ "$(<"'"${STATE_DIR}"'/gui")" = "running" ]' \
  'elif [ "$1" = "-x" ] && [ "$2" = "com.objective-see.lulu.extension" ]; then' \
  '  [ "$(<"'"${STATE_DIR}"'/extension")" = "enabled" ]' \
  'else' \
  '  exit 2' \
  'fi' >"${FAKE_BIN}/pgrep"
chmod 755 "${FAKE_BIN}/pgrep"

printf '%s\n' \
  '#!/bin/bash' \
  'printf "open\n" >>"'"${STATE_DIR}"'/commands"' \
  'printf "running\n" >"'"${STATE_DIR}"'/gui"' \
  'if [ -e "'"${STATE_DIR}"'/activation_requires_user" ]; then' \
  '  printf "waiting_user\n" >"'"${STATE_DIR}"'/extension"' \
  'elif [ ! -e "'"${STATE_DIR}"'/first_run_shown" ]; then' \
  '  : >"'"${STATE_DIR}"'/first_run_shown"' \
  '  plutil -create binary1 "'"${FAKE_CONFIG}"'/preferences.plist"' \
  '  plutil -insert allowApple -bool false "'"${FAKE_CONFIG}"'/preferences.plist"' \
  '  plutil -insert disabled -bool false "'"${FAKE_CONFIG}"'/preferences.plist"' \
  '  plutil -insert installTime -date "2026-07-19T13:00:00Z" "'"${FAKE_CONFIG}"'/preferences.plist"' \
  'else' \
  '  printf "enabled\n" >"'"${STATE_DIR}"'/extension"' \
  'fi' >"${FAKE_BIN}/open"
chmod 755 "${FAKE_BIN}/open"

printf '%s\n' \
  '#!/bin/bash' \
  'if [ "$1" = "-KILL" ] && [ "$2" = "LuLu" ]; then' \
  '  printf "close-gui\n" >>"'"${STATE_DIR}"'/commands"' \
  '  printf "stopped\n" >"'"${STATE_DIR}"'/gui"' \
  'elif [ "$1" = "-KILL" ] && [ "$2" = "com.objective-see.lulu.extension" ]; then' \
  '  printf "restart-extension\n" >>"'"${STATE_DIR}"'/commands"' \
  '  printf "stopped\n" >"'"${STATE_DIR}"'/extension"' \
  '  : >"'"${STATE_DIR}"'/extension_degraded"' \
  'elif [ "$1" = "-TERM" ] && [ "$2" = "com.objective-see.lulu.extension" ]; then' \
  '  printf "restart-extension\n" >>"'"${STATE_DIR}"'/commands"' \
  '  printf "stopped\n" >"'"${STATE_DIR}"'/extension"' \
  'else' \
  '  exit 1' \
  'fi' >"${FAKE_BIN}/killall"
chmod 755 "${FAKE_BIN}/killall"

printf '%s\n' \
  '#!/bin/bash' \
  'if [ "${1:-}" = "-v" ]; then exit 0; fi' \
  'exec "$@"' >"${FAKE_BIN}/sudo"
chmod 755 "${FAKE_BIN}/sudo"

printf '%s\n' '#!/bin/bash' 'exit 0' >"${FAKE_BIN}/sleep"
chmod 755 "${FAKE_BIN}/sleep"

printf '%s\n' \
  '#!/bin/bash' \
  'if [ "${1:-}" = "-e" ]; then printf "true\n"; exit 0; fi' \
  'printf "toggle-filter\n" >>"${STATE_DIR_PATH}/commands"' \
  'current_state="$(plutil -extract disabled raw "${FAKE_CONFIG_PATH}/preferences.plist" 2>/dev/null || true)"' \
  'if [ "$current_state" = "true" ]; then' \
  '  plutil -replace disabled -bool false "${FAKE_CONFIG_PATH}/preferences.plist"' \
  '  printf "enabled\n" >"${STATE_DIR_PATH}/extension"' \
  '  printf "启用\n"' \
  'else' \
  '  plutil -insert disabled -bool true "${FAKE_CONFIG_PATH}/preferences.plist" 2>/dev/null || plutil -replace disabled -bool true "${FAKE_CONFIG_PATH}/preferences.plist"' \
  '  printf "禁用\n"' \
  'fi' >"${FAKE_BIN}/osascript"
chmod 755 "${FAKE_BIN}/osascript"

output="$(FAKE_CONFIG_PATH="$FAKE_CONFIG" STATE_DIR_PATH="$STATE_DIR" PATH="${FAKE_BIN}:$PATH" "$UNDER_TEST" 2>&1)"
status="$?"
failures="0"

if [ "$status" -ne 0 ]; then
  printf 'FAIL: script exited %s\n%s\n' "$status" "$output"
  failures="$((failures + 1))"
fi

if [ ! -e "${STATE_DIR}/first_run_shown" ]; then
  printf 'FAIL: LuLu first-run setup was not shown\n'
  failures="$((failures + 1))"
fi

if [ "$(plutil -extract allowApple raw "${FAKE_CONFIG}/preferences.plist" 2>/dev/null)" != "false" ]; then
  printf 'FAIL: user-selected preferences were not preserved\n'
  failures="$((failures + 1))"
fi

if [ -e "${FAKE_CONFIG}/rules.plist" ]; then
  printf 'FAIL: reset rules were initialized before user setup\n'
  failures="$((failures + 1))"
fi

if [ "$(<"${STATE_DIR}/extension")" != "enabled" ]; then
  printf 'FAIL: LuLu network filter was not re-enabled after setup\n'
  failures="$((failures + 1))"
fi

expected_commands="$(printf 'close-gui\nopen\ntoggle-filter\ntoggle-filter')"
actual_commands="$(<"${STATE_DIR}/commands")"
if [ "$actual_commands" != "$expected_commands" ]; then
  printf 'FAIL: unexpected reset command order\nExpected:\n%s\nActual:\n%s\n' "$expected_commands" "$actual_commands"
  failures="$((failures + 1))"
fi

if [ "$failures" -ne 0 ]; then
  exit 1
fi

printf 'PASS: LuLu configuration reset opens first-run setup without preselected preferences\n'
