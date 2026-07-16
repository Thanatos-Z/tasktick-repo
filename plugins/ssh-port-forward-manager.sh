#!/bin/bash

SSH_HOST="${SSH_HOST:-cloud}"
CONFIG_DIR="${SSH_PORT_FORWARD_CONFIG_DIR:-$HOME/.config/ssh-port-forward-manager}"
PORTS_FILE="${SSH_PORT_FORWARD_PORTS_FILE:-$CONFIG_DIR/ports}"
ACTIVE_PORTS_FILE="${SSH_PORT_FORWARD_ACTIVE_PORTS_FILE:-$CONFIG_DIR/active-ports}"
CONTROL_SOCKET="${SSH_PORT_FORWARD_CONTROL_SOCKET:-$CONFIG_DIR/control.sock}"
SSH_BIN="${SSH_BIN:-/usr/bin/ssh}"
OSASCRIPT_BIN="${OSASCRIPT_BIN:-/usr/bin/osascript}"

set -u
umask 077

log() {
  local level="$1"
  local message="$2"

  printf '[%s] %s\n' "$level" "$message"
}

usage() {
  cat <<EOF
Usage:
  $0
  $0 add PORT
  $0 remove PORT
  $0 list
  $0 status
  $0 connect
  $0 disconnect

Without arguments, a Finder-hosted macOS dialog opens the port manager.
Each saved port forwards LOCAL_PORT to 127.0.0.1:REMOTE_PORT with the same
port number through the SSH host "$SSH_HOST".

Environment:
  SSH_HOST                         SSH config host. Default: $SSH_HOST
  SSH_PORT_FORWARD_CONFIG_DIR      State directory. Default: $CONFIG_DIR
  SSH_PORT_FORWARD_PORTS_FILE      Saved port list. Default: $PORTS_FILE
  SSH_PORT_FORWARD_ACTIVE_PORTS_FILE
                                   Active port snapshot. Default: $ACTIVE_PORTS_FILE
  SSH_PORT_FORWARD_CONTROL_SOCKET  SSH control socket. Default: $CONTROL_SOCKET
  SSH_BIN                          ssh executable. Default: $SSH_BIN
  OSASCRIPT_BIN                    osascript executable. Default: $OSASCRIPT_BIN
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

ensure_state() {
  if ! mkdir -p "$CONFIG_DIR"; then
    error_exit "Unable to create config directory: $CONFIG_DIR"
  fi

  if [ ! -e "$PORTS_FILE" ]; then
    if ! : > "$PORTS_FILE"; then
      error_exit "Unable to create ports file: $PORTS_FILE"
    fi
  fi

  if [ ! -e "$ACTIVE_PORTS_FILE" ]; then
    if ! : > "$ACTIVE_PORTS_FILE"; then
      error_exit "Unable to create active ports file: $ACTIVE_PORTS_FILE"
    fi
  fi
}

validate_port() {
  local port="$1"

  case "$port" in
    ""|*[!0-9]*)
      return 1
      ;;
  esac

  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    return 1
  fi
}

saved_ports() {
  awk '/^[0-9]+$/ && $1 >= 1 && $1 <= 65535 { print $1 }' "$PORTS_FILE" | sort -n -u
}

active_ports() {
  awk '/^[0-9]+$/ && $1 >= 1 && $1 <= 65535 { print $1 }' "$ACTIVE_PORTS_FILE" | sort -n -u
}

ports_summary() {
  local ports
  local summary=""
  local port

  ports="$(saved_ports)"
  if [ -z "$ports" ]; then
    printf '尚未保存任何端口。\n'
    return 0
  fi

  while IFS= read -r port; do
    if [ -z "$summary" ]; then
      summary="$port"
    else
      summary="$summary, $port"
    fi
  done <<< "$ports"

  printf '%s\n' "$summary"
}

select_action() {
  "$OSASCRIPT_BIN" - <<'APPLESCRIPT'
tell application "Finder"
    activate
    set selectedItem to choose from list {"连接全部已保存端口", "查看当前连接", "添加端口", "删除端口", "查看已保存端口", "断开当前连接"} ¬
        with title "SSH 端口转发" ¬
        with prompt "请选择操作：" ¬
        OK button name "继续" ¬
        cancel button name "退出"
end tell

if selectedItem is false then
    return "cancel"
else
    return item 1 of selectedItem
end if
APPLESCRIPT
}

prompt_for_port() {
  "$OSASCRIPT_BIN" - <<'APPLESCRIPT'
tell application "Finder"
    activate
    try
        set dialogResult to display dialog "请输入要转发的端口（1-65535）：" ¬
            with title "添加 SSH 端口" ¬
            default answer "9090" ¬
            buttons {"取消", "添加"} ¬
            default button "添加" ¬
            cancel button "取消"
        return text returned of dialogResult
    on error number -128
        return "cancel"
    end try
end tell
APPLESCRIPT
}

prompt_for_saved_port() {
  "$OSASCRIPT_BIN" - "$@" <<'APPLESCRIPT'
on run argv
    tell application "Finder"
        activate
        set selectedItem to choose from list argv ¬
            with title "删除 SSH 端口" ¬
            with prompt "请选择要从保存列表中删除的端口：" ¬
            OK button name "删除" ¬
            cancel button name "取消"
    end tell

    if selectedItem is false then
        return "cancel"
    else
        return item 1 of selectedItem
    end if
end run
APPLESCRIPT
}

show_dialog() {
  local title="$1"
  local message="$2"

  "$OSASCRIPT_BIN" - "$title" "$message" >/dev/null <<'APPLESCRIPT'
on run argv
    tell application "Finder"
        activate
        display dialog (item 2 of argv) ¬
            with title (item 1 of argv) ¬
            buttons {"好"} ¬
            default button "好"
    end tell
end run
APPLESCRIPT
}

normalize_action() {
  case "$1" in
    add|"添加端口")
      printf 'add\n'
      ;;
    remove|delete|"删除端口")
      printf 'remove\n'
      ;;
    list|show|"查看已保存端口")
      printf 'list\n'
      ;;
    status|current|"查看当前连接")
      printf 'status\n'
      ;;
    connect|start|"连接全部已保存端口")
      printf 'connect\n'
      ;;
    disconnect|stop|"断开当前连接")
      printf 'disconnect\n'
      ;;
    cancel)
      printf 'cancel\n'
      ;;
    *)
      return 1
      ;;
  esac
}

add_port() {
  local port="$1"
  local temp_file

  if ! validate_port "$port"; then
    error_exit "Invalid port: $port (expected 1-65535)"
  fi

  if saved_ports | awk -v target="$port" '$1 == target { found = 1 } END { exit !found }'; then
    log "NO_CHANGES" "Port already saved: $port"
    return 0
  fi

  temp_file="${PORTS_FILE}.tmp.$$"
  if ! { saved_ports; printf '%s\n' "$port"; } | sort -n -u > "$temp_file"; then
    command rm -f "$temp_file"
    error_exit "Unable to update ports file: $PORTS_FILE"
  fi
  if ! mv "$temp_file" "$PORTS_FILE"; then
    command rm -f "$temp_file"
    error_exit "Unable to replace ports file: $PORTS_FILE"
  fi

  log "SUCCESS" "Saved port: $port"
}

remove_port() {
  local port="$1"
  local temp_file

  if ! validate_port "$port"; then
    error_exit "Invalid port: $port (expected 1-65535)"
  fi

  if ! saved_ports | awk -v target="$port" '$1 == target { found = 1 } END { exit !found }'; then
    log "NO_CHANGES" "Port is not saved: $port"
    return 0
  fi

  temp_file="${PORTS_FILE}.tmp.$$"
  if ! saved_ports | awk -v target="$port" '$1 != target' > "$temp_file"; then
    command rm -f "$temp_file"
    error_exit "Unable to update ports file: $PORTS_FILE"
  fi
  if ! mv "$temp_file" "$PORTS_FILE"; then
    command rm -f "$temp_file"
    error_exit "Unable to replace ports file: $PORTS_FILE"
  fi

  log "SUCCESS" "Removed saved port: $port"
}

list_ports() {
  local summary

  summary="$(ports_summary)"
  log "INFO" "Saved ports: $summary"
  printf '%s\n' "$summary"
}

connection_is_active() {
  "$SSH_BIN" -S "$CONTROL_SOCKET" -O check "$SSH_HOST" >/dev/null 2>&1
}

connection_status_summary() {
  local ports
  local summary=""
  local port

  if ! connection_is_active; then
    : > "$ACTIVE_PORTS_FILE"
    printf '状态：未连接\n'
    return 0
  fi

  ports="$(active_ports)"
  if [ -z "$ports" ]; then
    printf '状态：已连接\nSSH 主机：%s\n当前端口：记录不可用\n' "$SSH_HOST"
    return 0
  fi

  while IFS= read -r port; do
    if [ -z "$summary" ]; then
      summary="$port"
    else
      summary="$summary, $port"
    fi
  done <<< "$ports"

  printf '状态：已连接\nSSH 主机：%s\n当前端口：%s\n' "$SSH_HOST" "$summary"
}

show_connection_status() {
  local summary="$1"

  log "INFO" "Managed SSH tunnel status checked"
  printf '%s\n' "$summary"
}

disconnect_tunnel() {
  local output

  if ! connection_is_active; then
    if [ -S "$CONTROL_SOCKET" ]; then
      command rm -f "$CONTROL_SOCKET"
    fi
    : > "$ACTIVE_PORTS_FILE"
    log "NO_CHANGES" "No managed SSH tunnel is active"
    return 0
  fi

  log "START" "Disconnecting managed SSH tunnel"
  if ! output="$("$SSH_BIN" -S "$CONTROL_SOCKET" -O exit "$SSH_HOST" 2>&1)"; then
    error_exit "Unable to disconnect SSH tunnel: $output"
  fi
  : > "$ACTIVE_PORTS_FILE"
  log "SUCCESS" "Managed SSH tunnel disconnected"
}

connect_tunnel() {
  local ports
  local port
  local output
  local ssh_args

  ports="$(saved_ports)"
  if [ -z "$ports" ]; then
    error_exit "No saved ports. Add at least one port before connecting."
  fi

  if connection_is_active; then
    log "INFO" "Replacing the existing managed SSH tunnel"
    disconnect_tunnel
  elif [ -S "$CONTROL_SOCKET" ]; then
    command rm -f "$CONTROL_SOCKET"
  fi
  : > "$ACTIVE_PORTS_FILE"

  ssh_args=(-M -S "$CONTROL_SOCKET" -o ControlPersist=yes -o ExitOnForwardFailure=yes -fN)
  while IFS= read -r port; do
    ssh_args+=( -L "127.0.0.1:${port}:127.0.0.1:${port}" )
    log "INFO" "Forward: 127.0.0.1:${port} -> ${SSH_HOST}:127.0.0.1:${port}"
  done <<< "$ports"

  log "START" "Connecting SSH tunnel through host: $SSH_HOST"
  if ! output="$("$SSH_BIN" "${ssh_args[@]}" "$SSH_HOST" 2>&1)"; then
    error_exit "Unable to establish SSH tunnel: $output"
  fi

  if ! connection_is_active; then
    error_exit "SSH command completed, but the managed tunnel is not active"
  fi
  if ! printf '%s\n' "$ports" > "$ACTIVE_PORTS_FILE"; then
    error_exit "Tunnel is active, but its port snapshot could not be saved: $ACTIVE_PORTS_FILE"
  fi
  log "SUCCESS" "All saved ports are now forwarded"
}

main() {
  local raw_action="${1:-}"
  local action
  local port="${2:-}"
  local summary
  local ports
  local saved_port
  local port_options

  if [ "$#" -gt 2 ]; then
    usage
    error_exit "Too many arguments"
  fi

  case "$raw_action" in
    -h|--help|help)
      usage
      exit 0
      ;;
  esac

  require_executable "$SSH_BIN"
  ensure_state

  if [ -z "$raw_action" ]; then
    require_executable "$OSASCRIPT_BIN"
    if ! raw_action="$(select_action)"; then
      error_exit "Unable to open the action selection dialog"
    fi
  fi

  if ! action="$(normalize_action "$raw_action")"; then
    usage
    error_exit "Unknown action: $raw_action"
  fi

  case "$action" in
    add)
      if [ -z "$port" ]; then
        require_executable "$OSASCRIPT_BIN"
        port="$(prompt_for_port)" || error_exit "Unable to open the port input dialog"
        if [ "$port" = "cancel" ]; then
          log "NO_CHANGES" "Action cancelled"
          exit 0
        fi
      fi
      add_port "$port"
      ;;
    remove)
      if [ -z "$port" ]; then
        ports="$(saved_ports)"
        if [ -z "$ports" ]; then
          log "NO_CHANGES" "No saved ports to remove"
          show_dialog "SSH 端口转发" "尚未保存任何端口。"
          exit 0
        fi
        require_executable "$OSASCRIPT_BIN"
        port_options=()
        while IFS= read -r saved_port; do
          port_options+=("$saved_port")
        done <<< "$ports"
        port="$(prompt_for_saved_port "${port_options[@]}")" || error_exit "Unable to open the port selection dialog"
        if [ "$port" = "cancel" ]; then
          log "NO_CHANGES" "Action cancelled"
          exit 0
        fi
      fi
      remove_port "$port"
      ;;
    list)
      summary="$(ports_summary)"
      list_ports
      if [ "$#" -eq 0 ]; then
        show_dialog "已保存的 SSH 端口" "$summary"
      fi
      ;;
    status)
      summary="$(connection_status_summary)"
      show_connection_status "$summary"
      if [ "$#" -eq 0 ]; then
        show_dialog "当前 SSH 连接" "$summary"
      fi
      ;;
    connect)
      connect_tunnel
      ;;
    disconnect)
      disconnect_tunnel
      ;;
    cancel)
      log "NO_CHANGES" "Action cancelled"
      ;;
  esac

  log "END" "SSH port forward manager completed"
}

main "$@"
