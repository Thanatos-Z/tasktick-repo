---
slug: blender-codex-workspace-docs
status: planned
intent: clear
pending-action: execute .omo/plans/blender-codex-workspace-docs.md with start-work
approach: Create a compact, executable README.md and AGENTS.md for a Codex + Blender automated modeling workspace, preserving the otherwise-empty target directory and adding no implementation artifacts.
---

# Draft: blender-codex-workspace-docs

## Components (topology ledger)
<!-- Lock the SHAPE before depth. One row per top-level component that can succeed or fail independently. -->
<!-- id | outcome (one line) | status: active|deferred | evidence path -->
README | A new user can understand the workspace, inputs, workflow, outputs, limitations, and troubleshooting | active | /Users/youzhi/workspace/blender space/README.md
AGENTS | Codex receives durable safety, file-layout, execution, and verification rules for Blender automation | active | /Users/youzhi/workspace/blender space/AGENTS.md
Verification | Both documents accurately match the observed local Blender environment and do not claim nonexistent assets | active | /Applications/Blender.app/Contents/MacOS/Blender

## Open assumptions (announced defaults)
<!-- Record any default you adopt instead of asking, so the user can veto it at the gate. -->
<!-- assumption | adopted default | rationale | reversible? -->
Language | Simplified Chinese, with exact English command/file names | Matches user communication and keeps commands unambiguous | yes
Directory layout | Document `scripts/`, `references/`, `models/`, `renders/`, and `exports/` as recommended future paths, not existing paths | User requested only two files and target directory is otherwise empty | yes
Test strategy | No automated tests; run Markdown/content checks and verify the documented Blender executable/version | Documentation-only change has no test harness | yes

## Findings (cited - path:lines)
- `/Users/youzhi/workspace/blender space` exists, is not a Git repository, and contains only an empty hidden macOS `Icon\r` file.
- `/Applications/Blender.app/Contents/MacOS/Blender --version` reports Blender 5.1.2.
- Local hardware inspection reports MacBook Pro, Apple M1 Pro, 32 GB memory, and a 16-core integrated GPU.
- Parent project instructions require Chinese communication, small reversible changes, preservation of user content, and verification before success claims.

## Decisions (with rationale)
- User selected the Codex + Blender automated modeling workspace orientation.
- Use the compact two-document approach rather than a production pipeline or multi-provider platform design.
- `README.md` is human onboarding; `AGENTS.md` is authoritative agent behavior and safety guidance.
- Treat `bpy` scripts as the reproducible modeling source while preserving `.blend` and exported assets as user content.
- Record Hyper3D/image-to-3D limitations without promising equivalent local generative inference on Apple Silicon.

## Scope IN
- Create `/Users/youzhi/workspace/blender space/README.md`.
- Create `/Users/youzhi/workspace/blender space/AGENTS.md`.
- Include exact quoted commands for the path containing a space.
- Verify Markdown structure, documented paths, Blender version, and absence of unintended target-directory changes.

## Scope OUT (Must NOT have)
- No extra directories, Blender models, Python scripts, renders, exports, dependencies, or configuration files.
- No Git initialization, commit, or push.
- No modification, rename, or deletion of the existing `Icon\r` file.
- No global package installation or third-party 3D model setup.

## Open questions
None. The user approved the recommended design by replying `1`, then authorized planning with `开撕`.

## Approval gate
status: approved
<!-- When exploration is exhausted and unknowns are answered, set status: awaiting-approval. -->
<!-- That durable record is the loop guard: on a later turn read it and resume at the gate instead of re-running exploration. -->
