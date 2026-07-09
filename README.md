# tasktick-repo

Tasktick-friendly local automation scripts.

## Scripts

### `backup-obsidian-vault.sh`

Backs up the Obsidian iCloud vault to GitHub without modifying the original vault directory.

Default configuration is kept at the top of the script:

```sh
VAULT="/Users/youzhi/Library/Mobile Documents/iCloud~md~obsidian/Documents/youzhi"
REPO="https://github.com/Thanatos-Z/my-obsidian.git"
BRANCH="main"
```

Run manually:

```sh
/Users/youzhi/workspace/Scripts/backup-obsidian-vault.sh
```

The script:

- creates a temporary directory with `mktemp -d`
- clones the GitHub backup repository into the temporary directory
- uses `rsync` to sync the Obsidian vault into the temporary Git worktree
- excludes Obsidian workspace/cache files, trash folders, `.DS_Store`, and temporary swap files
- commits and pushes only when changes exist
- prints Tasktick-readable status lines such as `[START]`, `[OK]`, `[NO_CHANGES]`, `[SUCCESS]`, `[FAIL]`, `[CLEANUP]`, and `[END]`
- removes the temporary directory on exit

## Safety Notes

- Do not initialize Git inside the Obsidian vault.
- Do not write files into the Obsidian vault from backup scripts.
- Keep credentials, tokens, private keys, and `.env` files out of this repository.
- Prefer small scripts with explicit status output so Tasktick logs are easy to inspect.
