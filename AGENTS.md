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
- 临时环境变量不得泄漏到调用者环境。优先使用 `VAR=value command` 或子 shell 限定作用域；确需 `export` 时，脚本结束前必须恢复调用者原值或 `unset`。不要只依赖 TaskTick 子进程退出时的系统清理；脚本还应兼容直接执行、`source` 和通过标准输入交给 shell 的场景。
- 环境变量可能包含凭据时，不要通过 `set -x`、状态输出或错误信息打印变量值。

## TaskTick CLI 注册规则

- 新脚本实现并完成最小相关验证后，使用 TaskTick CLI 直接注册，不再要求用户进入 TaskTick 图形界面手动创建。
- 注册前先确认 `tasktick` 可用，并运行 `tasktick list --filter all --json` 检查同名任务。TaskTick CLI 不按名称或脚本路径去重；同名任务已存在时不要再次创建，应报告现有任务并停止注册。
- 默认创建手动任务，使用 `--manual`；只有用户明确给出调度要求时才使用 `--repeat` 和 `--at`。
- `--shell` 必须与脚本 shebang 和实际语法一致：Bash 脚本使用 `/bin/bash`，Zsh 脚本使用 `/bin/zsh`。不要仅依赖 TaskTick 的默认 shell。
- 仓库内 `plugins/` 脚本注册时必须明确设置：

```sh
--cwd "/Users/youzhi/workspace/Scripts/plugins"
```

- 超时应按脚本行为明确设置；普通短任务默认使用 `--timeout 300`，确实需要更长时间时使用经过验证的值。
- 创建时使用绝对脚本路径和 `--json`，成功后再次运行 `tasktick list --filter all --json`，确认任务名称、启用状态和 `manual` 类型。
- Bash 脚本的标准注册命令示例：

```sh
tasktick create "任务名称" \
  --script "/Users/youzhi/workspace/Scripts/plugins/example.sh" \
  --shell /bin/bash \
  --cwd "/Users/youzhi/workspace/Scripts/plugins" \
  --timeout 300 \
  --manual \
  --json
```

- 注册是对本机 TaskTick 数据的写操作。以上规则授权在新脚本验证通过后创建对应任务，但不授权删除、重建或修改已有任务；涉及已有任务时先报告差异。

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
