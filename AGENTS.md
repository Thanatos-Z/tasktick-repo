# AGENTS.md

本文件给本地 AI Agent 使用，说明 `/Users/youzhi/workspace/Scripts` 仓库的约定。

## General Behavior

- 默认用中文和用户沟通。
- 直接、简洁、实用。
- 修改前先检查相关文件和当前 Git 状态。
- 优先做小、安全、可回滚的改动。
- 不要覆盖用户未提交修改。
- 不要创建提交或推送，除非用户明确要求。

## Repository Purpose

这是 Tasktick 和手动运行脚本的仓库。

当前核心脚本：

- `backup-obsidian-vault.sh`：将 Obsidian iCloud Vault 复制到临时 Git 工作区，同步到 GitHub，然后删除临时目录。

## Script Rules

- 默认使用 `#!/bin/bash`，除非用户明确要求其他语言。
- 脚本应保留顶部变量，方便用户修改路径、仓库、分支等配置。
- 依赖外部命令时先检查，例如 `git`、`rsync`、`mktemp`、`awk`。
- Tasktick 运行的脚本必须输出清晰状态，例如 `[START]`、`[INFO]`、`[OK]`、`[NO_CHANGES]`、`[SUCCESS]`、`[FAIL]`、`[CLEANUP]`、`[END]`。
- 失败时输出具体失败步骤、退出码，避免只给模糊错误。
- 有临时目录时使用 `mktemp -d` 和 `trap` 自动清理。

## Obsidian Backup Rules

- Obsidian vault 路径：

```text
/Users/youzhi/Library/Mobile Documents/iCloud~md~obsidian/Documents/youzhi
```

- Treat the vault as user content.
- Do not initialize Git inside the Obsidian vault.
- Do not modify, rename, reorganize, or delete files inside the Obsidian vault unless explicitly requested.
- Backup scripts should work from a temporary copy or temporary Git clone.
- Exclude cache, workspace state, trash folders, `.DS_Store`, and temporary files from backups.

## Python Rules

- Python scripts must use a project-local virtual environment when dependencies are needed.
- Prefer `uv`:

```sh
uv venv
```

- Do not install global Python packages unless explicitly requested.
- Inspect dependency files before adding or changing dependencies.

## Git Rules

- Before editing, run:

```sh
git status --short
```

- Do not use destructive commands such as `git reset --hard`, `git clean -fd`, or force push unless explicitly requested.
- Before GitHub state changes, inspect `gh auth status` and the target repository.
- Do not expose secrets or print sensitive values from `.env`, private keys, tokens, or credentials.
