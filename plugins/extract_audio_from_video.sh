#!/bin/bash

AUDIO_FORMAT="mp3"
AUDIO_CODEC="libmp3lame"
AUDIO_BITRATE="192k"

set -Eeuo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

CURRENT_STEP="初始化"
START_TIME="$(date +%s)"
TEMP_OUTPUT=""
FORCE="0"
GUI_MODE="0"

log() {
  printf '[%s] %s\n' "$1" "$2"
}

cleanup() {
  local exit_code="$?"

  if [[ -n "$TEMP_OUTPUT" && -e "$TEMP_OUTPUT" ]]; then
    rm -f -- "$TEMP_OUTPUT"
    log "CLEANUP" "已删除未完成的临时文件"
  fi

  return "$exit_code"
}

finish() {
  log "END" "耗时 $(( $(date +%s) - START_TIME )) 秒"
}

on_error() {
  local exit_code="$1"
  local line_no="$2"

  log "FAIL" "步骤失败：${CURRENT_STEP}（第 ${line_no} 行，退出码 ${exit_code}）" >&2
  exit "$exit_code"
}

fail() {
  log "FAIL" "$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'USAGE'
用法：extract_audio_from_video.sh [--force] [视频文件] [输出 MP3 文件]

从视频的第一条音轨导出 MP3。没有参数时会打开 macOS 文件选择框。

选项：
  --force    覆盖已存在的输出文件
  --help     显示帮助

示例：
  extract_audio_from_video.sh video.mp4
  extract_audio_from_video.sh video.mp4 audio.mp3
  extract_audio_from_video.sh --force video.mp4 audio.mp3
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少依赖：$1。请先运行：brew install ffmpeg" 127
}

choose_input_file() {
  /usr/bin/osascript <<'APPLESCRIPT'
tell application "Finder"
    activate
    try
        set selectedFile to choose file with prompt "请选择需要分离音频的视频文件"
        return POSIX path of selectedFile
    on error number -128
        return ""
    end try
end tell
APPLESCRIPT
}

choose_output_file() {
  /usr/bin/osascript - "$1" <<'APPLESCRIPT'
on run argv
    tell application "Finder"
        activate
        try
            set selectedFile to choose file name with prompt "请选择音频保存位置" default name (item 1 of argv)
            return POSIX path of selectedFile
        on error number -128
            return ""
        end try
    end tell
end run
APPLESCRIPT
}

INPUT_FILE=""
OUTPUT_FILE=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE="1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      fail "未知选项：$1"
      ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"
      elif [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="$1"
      else
        fail "参数过多。请运行 --help 查看用法"
      fi
      ;;
  esac
  shift
done

trap cleanup EXIT
trap 'on_error $? $LINENO' ERR

log "START" "开始从视频分离音频"

CURRENT_STEP="检查依赖"
require_command ffmpeg
require_command ffprobe
log "OK" "ffmpeg 和 ffprobe 可用"

if [[ -z "$INPUT_FILE" ]]; then
  GUI_MODE="1"
  CURRENT_STEP="选择视频文件"
  [[ "$(uname -s)" == "Darwin" ]] || fail "无参数选择模式仅支持 macOS；请传入视频文件路径"
  INPUT_FILE="$(choose_input_file)"
  if [[ -z "$INPUT_FILE" ]]; then
    log "END" "已取消选择"
    exit 0
  fi
fi

[[ -f "$INPUT_FILE" ]] || fail "视频文件不存在：$INPUT_FILE"

if [[ -z "$OUTPUT_FILE" ]]; then
  INPUT_NAME="$(basename "$INPUT_FILE")"
  DEFAULT_NAME="${INPUT_NAME%.*}.${AUDIO_FORMAT}"

  if [[ "$GUI_MODE" == "1" ]]; then
    CURRENT_STEP="选择输出位置"
    OUTPUT_FILE="$(choose_output_file "$DEFAULT_NAME")"
    if [[ -z "$OUTPUT_FILE" ]]; then
      log "END" "已取消保存"
      exit 0
    fi
  else
    OUTPUT_FILE="$(dirname "$INPUT_FILE")/$DEFAULT_NAME"
  fi
fi

if [[ "${OUTPUT_FILE##*.}" != "$AUDIO_FORMAT" ]]; then
  OUTPUT_FILE="${OUTPUT_FILE}.${AUDIO_FORMAT}"
fi

[[ "$INPUT_FILE" != "$OUTPUT_FILE" ]] || fail "输出文件不能与输入文件相同"
[[ -d "$(dirname "$OUTPUT_FILE")" ]] || fail "输出目录不存在：$(dirname "$OUTPUT_FILE")"

if [[ -e "$OUTPUT_FILE" && "$FORCE" != "1" ]]; then
  fail "输出文件已存在：${OUTPUT_FILE}。使用 --force 可覆盖" 2
fi

CURRENT_STEP="检查音轨"
if ! ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 -- "$INPUT_FILE" | grep -q '[0-9]'; then
  fail "视频中没有可用的音轨：$INPUT_FILE" 3
fi
log "OK" "已检测到音轨"

CURRENT_STEP="导出音频"
TEMP_OUTPUT="${OUTPUT_FILE}.part.$$"
log "INFO" "输入：$INPUT_FILE"
log "INFO" "输出：$OUTPUT_FILE"
ffmpeg -hide_banner -loglevel error -stats -y -i "$INPUT_FILE" \
  -map 0:a:0 -vn -c:a "$AUDIO_CODEC" -b:a "$AUDIO_BITRATE" -f "$AUDIO_FORMAT" "$TEMP_OUTPUT"
mv -f -- "$TEMP_OUTPUT" "$OUTPUT_FILE"
TEMP_OUTPUT=""

log "SUCCESS" "音频已保存：$OUTPUT_FILE"
finish
