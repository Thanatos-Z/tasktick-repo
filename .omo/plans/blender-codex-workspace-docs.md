# blender-codex-workspace-docs - Work Plan

## TL;DR (For humans)

**What you'll get:** Two concise Chinese Markdown files that turn the existing folder into a documented Codex + Blender automated modeling workspace: one human guide and one durable agent rulebook.

**Why this approach:** Keep onboarding separate from agent constraints, document only observed local capabilities, and treat future asset folders as conventions rather than pretending they already exist.

**What it will NOT do:** It will not create models, scripts, renders, asset directories, dependencies, a Git repository, or third-party AI integrations. It will not modify the existing Finder icon metadata file.

**Effort:** Quick
**Risk:** Low - the only operational risk is writing into a sandbox-protected directory, which requires a scoped permission grant.
**Decisions to sanity-check:** Simplified Chinese documentation; scripts are authoritative only for script-generated assets; existing user assets are never overwritten by default.

Your next move: run the plan with `$start-work`. Full execution detail follows below.

---

> TL;DR (machine): Quick, low-risk documentation task creating exactly README.md and AGENTS.md in the requested Blender workspace.

## Scope
### Must have
- Create non-empty UTF-8 `/Users/youzhi/workspace/blender space/README.md` in Simplified Chinese.
- Create non-empty UTF-8 `/Users/youzhi/workspace/blender space/AGENTS.md` in Simplified Chinese.
- README must cover purpose, verified environment, future directory conventions, end-to-end `bpy` workflow, quoted background command, request format, capability boundary, and troubleshooting.
- AGENTS must cover scope, preservation and overwrite rules, trustworthy script policy, output placement, runtime and visual verification, dependency safety, and concise delivery reporting.
- Preserve `/Users/youzhi/workspace/blender space/Icon\r` unchanged.
### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do not create any extra directory, model, script, render, export, dependency file, Blender add-on, or configuration file.
- Do not initialize Git, commit, push, rename, delete, or overwrite existing user content.
- Do not claim the documented future directories already exist.
- Do not describe Codex + `bpy` as equivalent to generative image-to-3D systems or include volatile pricing/specification tables.
- Do not create case variants such as `READMe.md`; the exact filename is `README.md`.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: none; documentation-only task with no existing test harness. Use shell assertions and direct file review after writing.
- Evidence: the per-task `.omo/evidence/task-1-...` through `task-4-...` files specified below, plus final verification evidence and a directory listing.
- Re-check Blender with `"/Applications/Blender.app/Contents/MacOS/Blender" --version`; only state Blender 5.1.2 as verified when the command confirms it during execution.
- Validate each document as non-empty UTF-8 Markdown and scan for placeholders (`TODO`, `TBD`, `<fill`, template comments).

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.
- Wave 1: Todo 1 preflight and safe staging preparation.
- Wave 2: Todos 2 and 3 draft README.md and AGENTS.md independently in a writable staging location using `apply_patch`.
- Wave 3: Todo 4 perform a single scoped, permission-approved installation into the target directory and verify final scope.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | none | 2, 3, 4 | none |
| 2 | 1 | 4 | 3 |
| 3 | 1 | 4 | 2 |
| 4 | 2, 3 | final verification | none |

## Todos
> Implementation + Test = ONE todo. Never separate.
- [x] 1. Reconfirm the target and verified local environment
  What to do / Must NOT do: Run read-only checks for target contents, Git status, Blender version, hardware summary, and exact existing filenames. Record the pre-change listing and metadata for `Icon\r`. Do not modify the target or print unrelated sensitive system information.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 2, 3, 4
  References (executor has NO interview context - be exhaustive): `/Users/youzhi/workspace/blender space`; `/Applications/Blender.app/Contents/MacOS/Blender`; `/Users/youzhi/workspace/Scripts/.omo/drafts/blender-codex-workspace-docs.md`
  Acceptance criteria (agent-executable): Target exists; `README.md` and `AGENTS.md` do not already exist; Blender version output is captured; `Icon\r` size/hash/metadata are captured; target is confirmed not to be a Git repository.
  QA scenarios (exact tool + invocation): happy: shell `ls -laO`, `find ... -maxdepth 1 -type f -print0`, Blender `--version`, and `shasum` capture expected facts; failure: if either target document unexpectedly exists, stop without overwriting and report the conflict. Evidence `.omo/evidence/task-1-blender-codex-workspace-docs.txt`.
  Commit: N | Target is not a Git repository and the user did not request a commit.

- [x] 2. Draft README.md as the human onboarding guide
  What to do / Must NOT do: Create a staged UTF-8 `README.md` with: project purpose; verified local environment; explicitly future/created-on-demand directory convention (`scripts/`, `references/`, `models/`, `renders/`, `exports/`); precise responsibilities for each directory; text/reference-to-script-to-Blender-to-preview/export workflow; a copyable command with both Blender and workspace paths quoted; a compact input checklist (object, dimensions, style, material, references, output format); concise Hyper3D boundary; and troubleshooting for missing executable, Python exception/exit code, paths with spaces, unavailable renderer/device, and missing output. Do not claim absent directories/assets exist or add volatile service pricing.
  Parallelization: Wave 2 | Blocked by: 1 | Blocks: 4 | Can parallelize with: 3
  References (executor has NO interview context - be exhaustive): Blender executable and environment evidence from Todo 1; target `/Users/youzhi/workspace/blender space/README.md`; planned directories under `/Users/youzhi/workspace/blender space/`; command form `"/Applications/Blender.app/Contents/MacOS/Blender" --background --python "/Users/youzhi/workspace/blender space/scripts/create_model.py"`.
  Acceptance criteria (agent-executable): Staged file is non-empty UTF-8 Markdown; includes all named sections; says directories are conventions created on demand; assigns `.blend` to `models/`, scripts to `scripts/`, references to `references/`, previews to `renders/`, and exchange files to `exports/`; command quotes every path containing spaces; contains no placeholders.
  QA scenarios (exact tool + invocation): happy: `file`, `test -s`, `rg` section/content assertions, and direct `sed` review; failure: a negative `rg` check rejects wording that claims future directories already exist or equates Codex with one-click image-to-3D. Evidence `.omo/evidence/task-2-blender-codex-workspace-docs.txt`.
  Commit: N | Documentation is installed only after both staged files pass review.

- [ ] 3. Draft AGENTS.md as the durable Codex operating contract
  What to do / Must NOT do: Create a staged UTF-8 `AGENTS.md` defining scope and Chinese communication; inspect-before-edit; scripts as primary source only for script-generated assets; preservation of hand-edited/user assets; incremental/versioned outputs; explicit approval before overwriting `.blend`, renders, or exports; trusted workspace script policy; rejection of unknown embedded/auto-run Python in `.blend`; exact directory responsibilities; no global package installs; Blender command/log/exit-code requirements; and delivery verification requiring expected non-empty outputs plus visual preview inspection for visual tasks. Do not authorize destructive operations or changes outside the workspace.
  Parallelization: Wave 2 | Blocked by: 1 | Blocks: 4 | Can parallelize with: 2
  References (executor has NO interview context - be exhaustive): `/Users/youzhi/workspace/blender space/AGENTS.md`; parent instructions `/Users/youzhi/workspace/Scripts/AGENTS.md` when accessible; target directory findings from Todo 1; directory contract defined in Todo 2.
  Acceptance criteria (agent-executable): Staged file is non-empty UTF-8 Markdown; explicitly preserves manual assets; requires new names/version suffixes by default; distinguishes inspected workspace scripts from unknown embedded scripts; requires runtime output existence/non-zero size and visual inspection; includes no placeholders or unsupported claims.
  QA scenarios (exact tool + invocation): happy: `file`, `test -s`, targeted `rg` assertions, and direct `sed` review; failure: negative assertions reject unconditional overwrite permission, global installation instructions, unverified success claims, or enabling unknown `.blend` auto-execution. Evidence `.omo/evidence/task-3-blender-codex-workspace-docs.txt`.
  Commit: N | No Git operations are in scope.

- [ ] 4. Install exactly the two approved documents and verify scope
  What to do / Must NOT do: Re-check that target `README.md` and `AGENTS.md` remain absent, then request the narrow filesystem elevation needed to copy the two reviewed staged files into `/Users/youzhi/workspace/blender space`. Do not use shell heredocs to author files; all content must have been created with `apply_patch`. After installation, verify bytes/content and compare the post-change target listing against Todo 1.
  Parallelization: Wave 3 | Blocked by: 2, 3 | Blocks: final verification | Can parallelize with: none
  References (executor has NO interview context - be exhaustive): staged README.md and AGENTS.md from Todos 2-3; target `/Users/youzhi/workspace/blender space/`; baseline evidence `.omo/evidence/task-1-blender-codex-workspace-docs.txt`.
  Acceptance criteria (agent-executable): Target contains exactly two new non-empty files named `README.md` and `AGENTS.md`; their checksums match staged files; `Icon\r` checksum/metadata remain unchanged; no directory, Git metadata, dependency, model, script, render, or export was added.
  QA scenarios (exact tool + invocation): happy: scoped elevated `cp`/`install`, then `find`, `file`, `test -s`, and `shasum` assertions; failure: if elevation is denied or a target file appears before copy, make no target write and report the precise blocker. Evidence `.omo/evidence/task-4-blender-codex-workspace-docs.txt`.
  Commit: N | User requested local files only.

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit: confirm every Must have is represented in the two installed documents and every Must NOT have is absent; record `.omo/evidence/final-f1-blender-codex-workspace-docs.txt`.
- [ ] F2. Documentation quality review: read both files end to end for concise Chinese, consistent directory semantics, correct quoting, no contradictions/placeholders, and no stale pricing/spec claims; record `.omo/evidence/final-f2-blender-codex-workspace-docs.txt`.
- [ ] F3. Real manual QA: execute the documented Blender `--version` command and shell-parse the example command to verify quoted paths stay intact; inspect installed files from the target directory; record `.omo/evidence/final-f3-blender-codex-workspace-docs.txt`.
- [ ] F4. Scope fidelity: compare pre/post directory listings and `Icon\r` checksum/metadata, ensuring exactly two files were added and no other state changed; record `.omo/evidence/final-f4-blender-codex-workspace-docs.txt`.

## Commit strategy
- No commit. The target is not a Git repository, and Git initialization is explicitly out of scope.
- Keep staged planning/evidence artifacts in `/Users/youzhi/workspace/Scripts/.omo/`; do not copy them into the Blender workspace.

## Success criteria
- `/Users/youzhi/workspace/blender space/README.md` and `/Users/youzhi/workspace/blender space/AGENTS.md` exist, are non-empty UTF-8 Markdown, and contain no placeholders.
- README accurately documents the observed Blender environment, future directory convention, executable workflow, capability boundary, and troubleshooting.
- AGENTS protects user assets, controls overwrites and script trust, and requires runtime plus visual verification.
- The target directory has no other new files or directories; `Icon\r` is unchanged.
- No dependency, Git repository, commit, model, script, render, or export is created.
