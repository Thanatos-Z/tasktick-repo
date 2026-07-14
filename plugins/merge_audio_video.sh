#!/bin/bash

# TaskTick / macOS 音视频合并脚本
# 流程：明确提示选择视频 -> 明确提示选择音频 -> 选择输出位置 -> swiftDialog 显示进度。

set -u

# TaskTick 通常不会加载用户的 shell 配置，因此补充常见命令路径。
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

show_message() {
  /usr/bin/osascript - "$1" "$2" <<'APPLESCRIPT' >/dev/null
on run argv
    display dialog (item 2 of argv) with title (item 1 of argv) buttons {"确定"} default button "确定"
end run
APPLESCRIPT
}

show_notification() {
  /usr/bin/osascript - "$1" "$2" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
    display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
}

show_step_prompt() {
  # 参数：标题、正文、继续按钮文字
  /usr/bin/osascript - "$1" "$2" "$3" <<'APPLESCRIPT'
on run argv
    try
        set continueButton to item 3 of argv
        set dialogResult to display dialog (item 2 of argv) ¬
            with title (item 1 of argv) ¬
            buttons {"取消", continueButton} ¬
            default button continueButton ¬
            cancel button "取消" ¬
            with icon note
        return button returned of dialogResult
    on error number -128
        return "取消"
    end try
end run
APPLESCRIPT
}

choose_input_file() {
  /usr/bin/osascript - "$1" <<'APPLESCRIPT'
on run argv
    tell application "Finder"
        activate
        try
            set selectedFile to choose file with prompt (item 1 of argv)
            return POSIX path of selectedFile
        on error number -128
            return ""
        end try
    end tell
end run
APPLESCRIPT
}

confirm_selected_file() {
  # 参数：文件类型、文件路径、确认按钮文字
  /usr/bin/osascript - "$1" "$2" "$3" <<'APPLESCRIPT'
on run argv
    try
        set confirmButton to item 3 of argv
        set dialogResult to display dialog ("已选择" & item 1 of argv & "：\n\n" & item 2 of argv) ¬
            with title (item 1 of argv & "确认") ¬
            buttons {"重新选择", confirmButton} ¬
            default button confirmButton ¬
            with icon note
        return button returned of dialogResult
    on error number -128
        return "重新选择"
    end try
end run
APPLESCRIPT
}

choose_output_file() {
  /usr/bin/osascript - "$1" <<'APPLESCRIPT'
on run argv
    tell application "Finder"
        activate
        try
            set selectedFile to choose file name ¬
                with prompt "第 3 步（共 3 步）：请选择合并后文件的保存位置和名称" ¬
                default name (item 1 of argv)
            return POSIX path of selectedFile
        on error number -128
            return ""
        end try
    end tell
end run
APPLESCRIPT
}

confirm_overwrite() {
  /usr/bin/osascript - "$1" <<'APPLESCRIPT'
on run argv
    try
        set dialogResult to display dialog ("文件已存在：\n\n" & item 1 of argv & "\n\n是否覆盖？") ¬
            with title "覆盖确认" ¬
            buttons {"取消", "覆盖"} ¬
            default button "覆盖" ¬
            cancel button "取消" ¬
            with icon caution
        return button returned of dialogResult
    on error number -128
        return "取消"
    end try
end run
APPLESCRIPT
}

find_command() {
  command -v "$1" 2>/dev/null || true
}

FFMPEG="$(find_command ffmpeg)"
FFPROBE="$(find_command ffprobe)"
if [[ -z "$FFMPEG" || -z "$FFPROBE" ]]; then
  show_message "缺少 ffmpeg" $'没有找到 ffmpeg 或 ffprobe。\n\n请先在终端运行：\nbrew install ffmpeg'
  exit 127
fi

# 必须定位到真正的 swiftDialog。不要优先使用 command -v dialog，
# 因为 Homebrew 的 ncurses dialog 也可能使用同名命令。
DIALOG=""
for candidate in \
  "/usr/local/bin/dialog" \
  "/opt/homebrew/bin/dialog" \
  "/Library/Application Support/Dialog/Dialog.app/Contents/MacOS/Dialog"
do
  if [[ -x "$candidate" ]]; then
    VERSION_OUTPUT="$("$candidate" --version 2>&1 || true)"
    # swiftDialog 通常输出纯版本号或包含 swiftDialog 名称；
    # ncurses dialog 通常输出“Version: ...”，必须排除。
    if printf '%s' "$VERSION_OUTPUT" | grep -qi 'swiftdialog'; then
      DIALOG="$candidate"
      break
    fi
    if printf '%s' "$VERSION_OUTPUT" | grep -Eq '^[[:space:]]*[0-9]+([.][0-9]+){2,3}[[:space:]]*$'; then
      DIALOG="$candidate"
      break
    fi
  fi
done

if [[ -z "$DIALOG" || ! -x "$DIALOG" ]]; then
  show_message "缺少 swiftDialog" $'没有找到可用的 swiftDialog。\n\n请先在终端运行：\nbrew install --cask swiftdialog\n\n然后确认：\n/usr/local/bin/dialog --version'
  exit 127
fi

# -------------------- 第 1 步：选择视频 --------------------
while true; do
  STEP_RESULT="$(show_step_prompt \
    "第 1 步：选择视频文件" \
    $'接下来打开的窗口用于选择【视频文件】。\n\n请选择只有画面的视频文件，然后点击“打开”。' \
    "选择视频文件")"

  if [[ "$STEP_RESULT" != "选择视频文件" ]]; then
    exit 0
  fi

  VIDEO_FILE="$(choose_input_file "第 1 步：请选择【视频文件】（只有画面的文件）")"
  if [[ -z "$VIDEO_FILE" ]]; then
    exit 0
  fi

  CONFIRM_RESULT="$(confirm_selected_file "视频文件" "$VIDEO_FILE" "确认视频文件")"
  if [[ "$CONFIRM_RESULT" == "确认视频文件" ]]; then
    break
  fi
done

# -------------------- 第 2 步：选择音频 --------------------
while true; do
  STEP_RESULT="$(show_step_prompt \
    "第 2 步：选择音频文件" \
    $'视频文件已经选择完成。\n\n接下来打开的窗口用于选择【音频文件】。请选择需要合并到视频中的声音文件。' \
    "选择音频文件")"

  if [[ "$STEP_RESULT" != "选择音频文件" ]]; then
    exit 0
  fi

  AUDIO_FILE="$(choose_input_file "第 2 步：请选择【音频文件】（声音文件）")"
  if [[ -z "$AUDIO_FILE" ]]; then
    exit 0
  fi

  CONFIRM_RESULT="$(confirm_selected_file "音频文件" "$AUDIO_FILE" "确认音频文件")"
  if [[ "$CONFIRM_RESULT" == "确认音频文件" ]]; then
    break
  fi
done

if [[ "$VIDEO_FILE" == "$AUDIO_FILE" ]]; then
  show_message "文件选择错误" "视频文件和音频文件不能是同一个文件。"
  exit 2
fi

# -------------------- 第 3 步：选择输出位置 --------------------
STEP_RESULT="$(show_step_prompt \
  "第 3 步：保存合并文件" \
  $'视频和音频均已选择完成。\n\n接下来请选择合并后 MP4 文件的保存位置和文件名。' \
  "选择保存位置")"

if [[ "$STEP_RESULT" != "选择保存位置" ]]; then
  exit 0
fi

VIDEO_NAME="$(basename "$VIDEO_FILE")"
VIDEO_STEM="${VIDEO_NAME%.*}"
DEFAULT_NAME="${VIDEO_STEM}_merged.mp4"

OUTPUT_FILE="$(choose_output_file "$DEFAULT_NAME")"
if [[ -z "$OUTPUT_FILE" ]]; then
  exit 0
fi

OUTPUT_NAME="$(basename "$OUTPUT_FILE")"
if [[ "$OUTPUT_NAME" != *.* ]]; then
  OUTPUT_FILE="${OUTPUT_FILE}.mp4"
else
  OUTPUT_EXT="$(printf '%s' "${OUTPUT_NAME##*.}" | tr '[:upper:]' '[:lower:]')"
  if [[ "$OUTPUT_EXT" != "mp4" ]]; then
    show_message "输出格式错误" "输出文件名必须以 .mp4 结尾。"
    exit 2
  fi
fi

if [[ "$OUTPUT_FILE" == "$VIDEO_FILE" || "$OUTPUT_FILE" == "$AUDIO_FILE" ]]; then
  show_message "无法保存" "输出文件不能与输入文件相同。"
  exit 2
fi

if [[ -e "$OUTPUT_FILE" ]]; then
  OVERWRITE="$(confirm_overwrite "$OUTPUT_FILE")"
  if [[ "$OVERWRITE" != "覆盖" ]]; then
    exit 0
  fi
fi

# -------------------- 进度窗口 --------------------
# swiftDialog 官方默认使用 /var/tmp。TaskTick 的私有 TMPDIR 可能导致
# 独立运行的 Dialog.app 无法持续监听命令文件。
COMMAND_FILE="/var/tmp/tasktick-merge-command-$$.log"
LOG_FILE="/var/tmp/tasktick-merge-error-$$.log"
rm -f "$COMMAND_FILE" "$LOG_FILE"
: > "$COMMAND_FILE"
: > "$LOG_FILE"

DIALOG_PID=""
SUCCESS=0

cleanup() {
  if [[ -n "$DIALOG_PID" ]] && kill -0 "$DIALOG_PID" 2>/dev/null; then
    printf 'quit:\n' >> "$COMMAND_FILE" 2>/dev/null || true
    wait "$DIALOG_PID" 2>/dev/null || true
  fi

  rm -f "$COMMAND_FILE"

  if [[ "$SUCCESS" -eq 1 ]]; then
    rm -f "$LOG_FILE"
  fi
}
trap cleanup EXIT INT TERM

sanitize_dialog_text() {
  printf '%s' "$1" | tr '\r\n' '  '
}

update_dialog() {
  # 参数：百分比、进度文字、正文
  {
    printf 'progress: show\n'
    printf 'progress: %s\n' "$1"
    printf 'progresstext: %s\n' "$(sanitize_dialog_text "$2")"
    printf 'message: %s\n' "$(sanitize_dialog_text "$3")"
  } >> "$COMMAND_FILE"
}

"$DIALOG" \
  --title "音视频合并" \
  --message "正在准备 ffmpeg，请勿移动或删除源文件。" \
  --presentation \
  --icon "SF=film.stack" \
  --infobox "FFmpeg 音视频合并" \
  --progress 100 \
  --progresstext "准备中 · 0%" \
  --commandfile "$COMMAND_FILE" \
  --ontop \
  --showonallscreens &
DIALOG_PID=$!

# 给 Dialog.app 足够时间建立命令文件监听。
sleep 0.8

if ! kill -0 "$DIALOG_PID" 2>/dev/null; then
  DIALOG_ERROR="$(tail -n 20 "$LOG_FILE" 2>/dev/null || true)"
  show_message "进度窗口启动失败" $'swiftDialog 没有成功启动。\n\n请在终端检查：\n'"$DIALOG"$' --version\n\n'"$DIALOG_ERROR"
  exit 1
fi

# 即使某些版本没有在初始布局中创建进度条，也强制创建并显示。
{
  printf 'progress: create\n'
  printf 'progress: 0\n'
  printf 'progresstext: 准备中 · 0%%\n'
  printf 'activate:\n'
} >> "$COMMAND_FILE"

# 将 Dialog.app 拉到前台，避免被文件选择窗口留在后面。
/usr/bin/open -a "Dialog" >/dev/null 2>&1 || true
sleep 0.3

probe_duration() {
  "$FFPROBE" \
    -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$1" 2>/dev/null | awk 'NR == 1 && $1 ~ /^[0-9]+([.][0-9]+)?$/ { print $1 }'
}

VIDEO_DURATION="$(probe_duration "$VIDEO_FILE")"
AUDIO_DURATION="$(probe_duration "$AUDIO_FILE")"

# 因为使用 -shortest，输出时长取两个输入中较短的一个。
TOTAL_US="$(awk -v video="$VIDEO_DURATION" -v audio="$AUDIO_DURATION" '
BEGIN {
    duration = 0
    if (video > 0 && audio > 0) {
        duration = (video < audio ? video : audio)
    } else if (video > 0) {
        duration = video
    } else if (audio > 0) {
        duration = audio
    }

    if (duration > 0) {
        printf "%.0f", duration * 1000000
    } else {
        print 0
    }
}' )"

format_time() {
  awk -v microseconds="$1" 'BEGIN {
      seconds = int(microseconds / 1000000)
      hours = int(seconds / 3600)
      minutes = int((seconds % 3600) / 60)
      secs = seconds % 60
      printf "%02d:%02d:%02d", hours, minutes, secs
  }'
}

run_ffmpeg_attempt() {
  STAGE="$1"
  shift

  rm -f "$OUTPUT_FILE"
  update_dialog 0 "$STAGE · 0%" "正在处理：$STAGE"
  printf '\n===== %s =====\n' "$STAGE" >> "$LOG_FILE"

  "$FFMPEG" \
    -hide_banner \
    -y \
    -nostdin \
    -loglevel error \
    -stats_period 0.25 \
    -progress pipe:1 \
    -nostats \
    "$@" \
    2>> "$LOG_FILE" |
  while IFS='=' read -r KEY VALUE; do
    case "$KEY" in
      out_time_us|out_time_ms)
        case "$VALUE" in
          ''|*[!0-9]*) continue ;;
        esac

        # FFmpeg 旧版本可能只输出 out_time_ms；该字段实际同样以微秒计。
        if [[ "$TOTAL_US" -gt 0 ]]; then
          PERCENT=$((VALUE * 100 / TOTAL_US))
          if [[ "$PERCENT" -gt 99 ]]; then
            PERCENT=99
          elif [[ "$PERCENT" -lt 0 ]]; then
            PERCENT=0
          fi

          TIME_TEXT="$(format_time "$VALUE")"
          update_dialog "$PERCENT" "$STAGE · ${PERCENT}% · ${TIME_TEXT}" "正在处理：$STAGE"
        else
          TIME_TEXT="$(format_time "$VALUE")"
          update_dialog 0 "$STAGE · 已处理 ${TIME_TEXT}" "正在处理：$STAGE（无法读取总时长）"
        fi
        ;;
      progress)
        if [[ "$VALUE" == "end" ]]; then
          update_dialog 99 "$STAGE · 即将完成" "正在写入输出文件…"
        fi
        ;;
    esac
  done

  FFMPEG_STATUS=${PIPESTATUS[0]}
  return "$FFMPEG_STATUS"
}

COMMON_INPUTS=(
  -i "$VIDEO_FILE"
  -i "$AUDIO_FILE"
  -map 0:v:0
  -map 1:a:0
)

# 方案 1：直接复制音视频流，速度最快且没有重新编码损失。
if run_ffmpeg_attempt \
  "无损快速合并" \
  "${COMMON_INPUTS[@]}" \
  -c copy \
  -shortest \
  -movflags +faststart \
  "$OUTPUT_FILE"; then
  MODE="无损快速合并"
else
  # 方案 2：保留原视频，只把音频转换成 AAC。
  if run_ffmpeg_attempt \
    "视频无损，音频转换为 AAC" \
    "${COMMON_INPUTS[@]}" \
    -c:v copy \
    -c:a aac \
    -b:a 192k \
    -shortest \
    -movflags +faststart \
    "$OUTPUT_FILE"; then
    MODE="视频无损、音频转换为 AAC"
  else
    # 方案 3：完整转换，兼容性最高。
    if run_ffmpeg_attempt \
      "转换为 H.264 和 AAC" \
      "${COMMON_INPUTS[@]}" \
      -c:v libx264 \
      -preset medium \
      -crf 20 \
      -c:a aac \
      -b:a 192k \
      -shortest \
      -movflags +faststart \
      "$OUTPUT_FILE"; then
      MODE="转换为 H.264 + AAC"
    else
      rm -f "$OUTPUT_FILE"
      update_dialog 0 "合并失败" "ffmpeg 无法处理这两个文件。"
      sleep 1
      printf 'quit:\n' >> "$COMMAND_FILE"
      wait "$DIALOG_PID" 2>/dev/null || true
      DIALOG_PID=""

      show_message "合并失败" $'ffmpeg 无法合并这两个文件。\n\n错误日志保存在：\n'"$LOG_FILE"
      exit 1
    fi
  fi
fi

SUCCESS=1
update_dialog 100 "合并完成 · 100%" "文件已经成功保存。"
sleep 2
printf 'quit:\n' >> "$COMMAND_FILE"
wait "$DIALOG_PID" 2>/dev/null || true
DIALOG_PID=""

show_notification "音视频合并完成" "$(basename "$OUTPUT_FILE")"
show_message "合并完成" $'处理方式：'"$MODE"$'\n\n文件已保存到：\n'"$OUTPUT_FILE"

# 在 Finder 中选中生成的文件。
/usr/bin/open -R "$OUTPUT_FILE" >/dev/null 2>&1 || true

printf '合并完成：%s\n' "$OUTPUT_FILE"
printf '处理方式：%s\n' "$MODE"
