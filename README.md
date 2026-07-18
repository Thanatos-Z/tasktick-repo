# Tasktick 脚本仓库

适合 Tasktick 和手动运行的本地自动化脚本。

## 脚本

### `plugins/ssh-port-forward-manager.sh`

通过 macOS 弹窗管理一组持久化的 SSH 本地端口转发。默认使用 `~/.ssh/config` 中的 `cloud` 主机配置，因此服务器的 SSH 端口仍由 `cloud` 配置中的 `Port 8022` 决定。

手动运行：

```sh
/Users/youzhi/workspace/Scripts/plugins/ssh-port-forward-manager.sh
```

弹窗支持添加端口、删除端口、查看已保存端口、连接全部端口、查看当前连接和断开连接。“查看当前连接”会显示隧道是否在线，以及本次连接实际采用的端口。端口默认保存在：

```text
~/.config/ssh-port-forward-manager/ports
```

也可以从命令行操作：

```sh
plugins/ssh-port-forward-manager.sh add 9090
plugins/ssh-port-forward-manager.sh remove 9090
plugins/ssh-port-forward-manager.sh list
plugins/ssh-port-forward-manager.sh status
plugins/ssh-port-forward-manager.sh connect
plugins/ssh-port-forward-manager.sh disconnect
```

每个端口使用相同的本地和服务器端口，例如保存 `9090` 会建立 `127.0.0.1:9090 -> cloud:127.0.0.1:9090`。脚本不会修改服务器防火墙，也不会将端口开放给局域网或公网；它只在本机回环地址上建立 SSH 隧道。出于安全和系统限制，脚本不支持一次转发全部 `1-65535` 端口。

### `plugins/backup-obsidian-vault.sh`

将 Obsidian iCloud Vault 备份到 GitHub，不修改原始 vault 目录。

默认配置保留在脚本顶部：

```sh
VAULT="/Users/youzhi/Library/Mobile Documents/iCloud~md~obsidian/Documents/youzhi"
REPO="https://github.com/Thanatos-Z/my-obsidian.git"
BRANCH="main"
```

手动运行：

```sh
/Users/youzhi/workspace/Scripts/plugins/backup-obsidian-vault.sh
```

脚本行为：

- 使用 `mktemp -d` 创建临时目录
- 将 GitHub 备份仓库 clone 到临时目录
- 使用 `rsync` 将 Obsidian vault 同步到临时 Git 工作区
- 排除 Obsidian workspace/cache 文件、废纸篓目录、`.DS_Store` 和临时 swap 文件
- 只有检测到变化时才 commit 和 push
- 输出 Tasktick 可读的状态行，例如 `[START]`、`[OK]`、`[NO_CHANGES]`、`[SUCCESS]`、`[FAIL]`、`[CLEANUP]`、`[END]`
- 退出时删除临时目录

### `plugins/codex-trace-suppression.sh`

为 Codex 日志数据库安装或删除 SQLite trigger，用于控制新的 `TRACE` 日志是否写入 `logs` 表。

手动运行：

```sh
/Users/youzhi/workspace/Scripts/plugins/codex-trace-suppression.sh
```

无参数运行时，脚本会优先通过 macOS 弹窗选择启用或停用。也可以传入明确动作：

```sh
/Users/youzhi/workspace/Scripts/plugins/codex-trace-suppression.sh enable
/Users/youzhi/workspace/Scripts/plugins/codex-trace-suppression.sh disable
/Users/youzhi/workspace/Scripts/plugins/codex-trace-suppression.sh status
```

TaskTick 当前公开源码里没有看到独立的“运行前选项参数”字段；脚本文件任务会读取文件内容后通过 shell 运行。要在 TaskTick 里固定动作，可以设置环境变量：

```sh
TRACE_SUPPRESSION_ACTION=enable
TRACE_SUPPRESSION_ACTION=disable
TRACE_SUPPRESSION_ACTION=status
```

Codex TRACE 脚本默认操作：

```sh
$HOME/.codex/logs_2.sqlite
```

如需指定其他数据库，可传入 `DB_PATH`：

```sh
DB_PATH="/path/to/logs_2.sqlite" /Users/youzhi/workspace/Scripts/plugins/codex-trace-suppression.sh enable
```

### `plugins/merge_audio_video.sh`

在 macOS 上通过图形化窗口依次选择视频、音频和输出位置，将两者合并为 MP4 文件，并使用 swiftDialog 显示处理进度。文件选择和保存窗口由 Finder 承载，可正常使用 `⌘V`、`⌘A`、`⌘⇧G` 等系统快捷键。

依赖：

```sh
brew install ffmpeg
brew install --cask swiftdialog
```

手动运行：

```sh
/Users/youzhi/workspace/Scripts/plugins/merge_audio_video.sh
```

脚本会优先直接复制音视频流；如果格式不兼容，则依次尝试将音频转换为 AAC，或将视频和音频完整转换为 H.264 与 AAC。输出时长取视频和音频中较短的一方。处理完成后，脚本会在 Finder 中选中生成的 MP4 文件。

### `plugins/extract_audio_from_video.sh`

从视频的第一条音轨导出 MP3 文件，默认使用 192 kbps。依赖 `ffmpeg` 和 `ffprobe`：

```sh
brew install ffmpeg
```

无参数运行时会在 macOS 上打开由 Finder 承载的文件选择框，可正常使用 `⌘V`、`⌘A`、`⌘⇧G` 等系统快捷键：

```sh
/Users/youzhi/workspace/Scripts/plugins/extract_audio_from_video.sh
```

也可直接传入路径，适合终端或自动化任务：

```sh
/Users/youzhi/workspace/Scripts/plugins/extract_audio_from_video.sh video.mp4
/Users/youzhi/workspace/Scripts/plugins/extract_audio_from_video.sh video.mp4 audio.mp3
```

输出文件已存在时脚本默认停止，明确传入 `--force` 才会覆盖。

## 安全注意事项

- 不要在 Obsidian vault 内初始化 Git。
- 备份脚本不要向 Obsidian vault 写入文件。
- 不要将凭据、token、私钥和 `.env` 文件放入本仓库。
- 优先写小脚本，并输出明确状态，方便检查 Tasktick 日志。

## 新脚本约定

- 脚本可能由 Tasktick 运行，因此每个有意义的步骤都应输出简洁状态行。
- 使用稳定的状态前缀，例如 `[START]`、`[INFO]`、`[OK]`、`[NO_CHANGES]`、`[SUCCESS]`、`[FAIL]`、`[CLEANUP]`、`[END]`。
- 错误输出应尽量说明失败步骤和退出码。
- 需要依赖的 Python 脚本应使用项目本地虚拟环境，优先用 `uv venv` 创建。
- 临时环境变量优先通过 `VAR=value command` 或子 shell 限定作用域；确需 `export` 时，脚本结束前必须恢复原值或执行 `unset`。不要在日志中打印凭据或其他敏感变量值。

## 使用 CLI 加入 TaskTick

新脚本完成并通过相关验证后，直接使用 TaskTick CLI 注册，默认创建手动任务，无需再进入 TaskTick 图形界面创建。注册前必须通过 `tasktick list --filter all --json` 检查同名任务，避免重复创建。

Bash 脚本示例：

```sh
tasktick create "任务名称" \
  --script "/Users/youzhi/workspace/Scripts/plugins/example.sh" \
  --shell /bin/bash \
  --cwd "/Users/youzhi/workspace/Scripts/plugins" \
  --timeout 300 \
  --manual \
  --json
```

Zsh 脚本将 `--shell` 改为 `/bin/zsh`。`--shell` 应与脚本 shebang 和实际语法一致；只有明确需要定时运行时，才用 `--repeat` 和 `--at` 代替 `--manual`。创建后再次运行：

```sh
tasktick list --filter all --json
```

确认任务已启用且类型为 `manual`。TaskTick CLI 当前不会按任务名或脚本路径去重，也不提供已有任务的更新命令，因此不要通过重复执行 `create` 来修改任务。
