# AGENTS.md

本文件给本地 AI Agent 使用，说明 `/Users/youzhi/workspace/Scripts` 仓库的约定。

## 通用行为

- 默认用中文和用户沟通。
- 直接、简洁、实用。
- 修改前先检查相关文件和当前 Git 状态。
- 优先做小、安全、可回滚的改动。
- 先确认真实运行环境，再用一次 Touch ID 完成权限操作，并逐项验证实际结果。
- 不要覆盖用户未提交修改。
- 不要创建提交或推送，除非用户明确要求。

## 仓库用途

这是 Tasktick 和手动运行脚本的仓库。

当前核心脚本：

- `plugins/backup-obsidian-vault.sh`：将 Obsidian iCloud Vault 复制到临时 Git 工作区，同步到 GitHub，然后删除临时目录。
- `plugins/codex-trace-suppression.sh`：通过 macOS 选项弹窗、命令行参数或环境变量控制 Codex TRACE 日志的 SQLite trigger。

## 脚本规则

- 默认使用 `#!/bin/bash`，除非用户明确要求其他语言。
- 新脚本默认放在 `plugins/` 目录下。
- 脚本应保留顶部变量，方便用户修改路径、仓库、分支等配置。
- 依赖外部命令时先检查，例如 `git`、`rsync`、`mktemp`、`awk`。
- macOS 脚本需要管理员权限时，优先检查并实际验证 `sudo -v` 是否能通过 PAM 触发 Touch ID；确认当前运行环境不支持后，再采用 AppleScript 管理员授权或其他认证方式。
- 新建或修改带选项参数的脚本时，先询问用户是否需要添加 macOS 图形选项弹窗，不要自行决定。
- macOS 脚本使用 AppleScript 的 `choose file` 或 `choose file name` 时，应先激活 Finder，并让 Finder 承载文件面板。直接由 `osascript` 显示面板时，它可能不会成为前台应用，导致 `⌘V`、`⌘A`、`⌘⇧G` 等系统快捷键仍发送给终端或 Tasktick。
- 脚本可能由 Tasktick 自动运行，必须为每个关键步骤输出清晰、稳定的状态信息，方便从 Tasktick 日志直接判断进度和失败点。
- 状态前缀优先使用 `[START]`、`[INFO]`、`[OK]`、`[NO_CHANGES]`、`[SUCCESS]`、`[FAIL]`、`[CLEANUP]`、`[END]`。
- 失败时输出具体失败步骤、退出码，避免只给模糊错误。
- 有临时目录时使用 `mktemp -d` 和 `trap` 自动清理。

## Obsidian 备份规则

- Obsidian vault 路径：

```text
/Users/youzhi/Library/Mobile Documents/iCloud~md~obsidian/Documents/youzhi
```

- 将 vault 视为用户内容。
- 不要在 Obsidian vault 内初始化 Git。
- 除非用户明确要求，不要修改、重命名、重组或删除 Obsidian vault 内的文件。
- 备份脚本应基于临时副本或临时 Git clone 工作。
- 备份时排除 cache、workspace 状态、废纸篓目录、`.DS_Store` 和临时文件。

## Python 规则

- Python 脚本需要依赖时，必须使用项目本地虚拟环境。
- 优先使用 `uv`：

```sh
uv venv
```

- 除非用户明确要求，不要安装全局 Python 包。
- 添加或修改依赖前，先检查依赖文件。

## Git 规则

- 修改前运行：

```sh
git status --short
```

- 除非用户明确要求，不要使用 `git reset --hard`、`git clean -fd`、force push 等破坏性操作。
- 执行 GitHub 状态变更前，先检查 `gh auth status` 和目标仓库。
- 不要暴露 secret，也不要打印 `.env`、私钥、token 或凭据中的敏感值。
