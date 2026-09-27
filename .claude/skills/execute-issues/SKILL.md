---
name: execute-issues
description: Execute GitHub issues for a phase sequentially - implement, validate, commit, push, and generate a report.
---

# Skill: Execute GitHub Issues

Execute GitHub issues for a phase sequentially: implement, validate, commit, push, and
generate a report.

## Usage

```
/execute-issues <label> [--issue MYRMEX-###] [--dry-run]
```

The `<label>` is the GitHub phase label exactly as it appears (e.g., `v0.2::phase`).

- `/execute-issues v0.2::phase` -- execute all issues labeled `v0.2::phase`
- `/execute-issues v0.2::phase --issue MYRMEX-003` -- execute a single issue from that phase
- `/execute-issues v0.2::phase --dry-run` -- show execution plan without making changes

> [!IMPORTANT]
> **Generate every line fresh.** Every line of code, test, script, and config must be written by the
> executing agent in-session. Never `git checkout`, `git cherry-pick`, or otherwise recover code from
> another branch, ref, repository, or a previous run to satisfy an issue — the generated run is the point.

## Instructions

### Step 0: Verify prerequisites

1. Confirm we are on the working branch (`main`)
2. Confirm working tree is clean (`git status`)
3. Confirm `gh` is authenticated
4. Parse the label to determine the phase: label `v0.2::phase` -> phase `v0.2`
5. Fetch issues from GitHub:
   ```bash
   gh issue list --label "{label}" --state open --limit 100
   ```
6. Read the phase issues file for detailed descriptions: `specification/implementation/v{A.B}-issues.md`
7. If a GitHub report exists (`specification/implementation/v{A.B}-github-report.md`), read the MYRMEX-to-GitHub# mapping
8. Read [specification/ROADMAP.md](../../../specification/ROADMAP.md) for the version goal and the phase (`vA.B`) DoD/Tests, [specification/ARCHITECTURE.md](../../../specification/ARCHITECTURE.md) for the contracts the issue must honor, and [specification/VISION.md](../../../specification/VISION.md) for the product vision and scope.

### Step 1: Build execution queue

From the GitHub issue list, build an ordered queue based on dependencies:
- Parse MYRMEX-### IDs from issue titles (format: `MYRMEX-###: {title}`)
- Determine dependency order from the phase issues file dependency tree
- Issues with no unmet dependencies go first
- Closed issues are already excluded (Step 0 fetches `--state open`), so a re-run resumes where the
  last one stopped
- If `--issue MYRMEX-###` is specified, execute only that issue (but verify its dependencies are closed)

Show the user the execution plan and ask for confirmation.

### Step 2: Execute each issue (loop)

For each issue in the queue:

#### 2a. Assign and announce

Print: `--- Starting MYRMEX-###: {title} ---`

#### 2b. Read issue details

Read the full issue description from the phase issues file (the detailed section for this MYRMEX-###).

#### 2c. Implement

Execute the tasks described in the issue. Follow the conventions in `CLAUDE.md` and the
architecture in `specification/ARCHITECTURE.md`. Route by component ([ARCHITECTURE.md](../../../specification/ARCHITECTURE.md) §2):

- **Sim** (`res://sim/`): the pure-data simulation — no `Node`, no scene tree, no network. Deterministic: every random draw through `rng.gd`, agents processed in id order, the fixed tick phase order (ARCHITECTURE.md §Time and the tick). Conservation holds: food/resource units move only through the defined flows.
- **View / UI** (`res://view/`, `res://ui/`): read sim state and render it; observer actions become commands applied at tick boundaries. They never mutate sim state directly, and the sim never imports from them.
- **LLM** (`res://llm/`): providers behind the abstracted seam; the model only writes/revises the strategy program, validated before apply. `MOCK` in tests. **The model never controls an individual myrmek.**
- **Data** (`res://data/`): parameter defaults are `.tres` Resources, never hardcoded constants.
- **Contract changes:** any change to a stable seam — the tick phase order, `StateView`, the policy schema, `StrategyRunner`, the task shape, the LLM provider interface, or the save format (ARCHITECTURE.md §Contracts) — updates `specification/ARCHITECTURE.md` **AND** its contract test, in the same commit.
- Follow existing style/patterns; keep each phase self-contained (don't pull later phases in early — prototype-first, simplicity-first). Fixed terminology: **myrmek** (never "ant"), **nest** (never "colony").

#### 2d. Validate

Run validation checks (Godot, headless):

1. **Tests:** `scripts/test.sh` — the headless test suite (unit + the contract tests pinning the seams), where tests exist.
2. **Determinism:** when the change touches `res://sim/`, run the suite's determinism check (same seed → identical state hash after N ticks). A determinism break is a validation failure even when every other test passes.
3. **Parse/load:** a headless import/run (`godot --headless --path . --quit` or the project's check script) to confirm every changed script parses and loads.
4. **Contract consistency:** the touched seams match `specification/ARCHITECTURE.md` and their contract tests.
5. **Acceptance criteria:** go through each criterion from the issue and verify against the phase DoD/Tests in `specification/ROADMAP.md`.

Record pass/fail for each check. **Tests are part of the work.** No paid APIs in
validation/CI: the LLM provider is **`MOCK` by default**; a live model call is permitted but opt-in.

#### 2e. Commit

```bash
git add {specific files created/modified}
git commit -m "$(cat <<'EOF'
MYRMEX-###: {title}

{1-2 sentence summary of what was implemented}

Closes #{github-issue-number}

Co-Authored-By: <the running model's trailer> <noreply@anthropic.com>
EOF
)"
```

#### 2f. Push

```bash
git push
```

#### 2g. Close issue with summary

```bash
gh issue close {issue-number} --comment "$(cat <<'EOF'
## Implementation Summary

**Commit:** {commit-hash}
**Files changed:** {count}

### What was done
{bullet list of key changes}

### Validation
{pass/fail status for each check}

### Acceptance criteria
{checklist with pass/fail}
EOF
)"
```

#### 2g-bis. Emit tracking events

One line per site, via `python3 -m tracker.emit <type> --emitter skill:execute-issues --scope
phase=..,version=..,step=execute-issues,issue=MYRMEX-### [...]`. 2a → `issue.start` (`size`, `area`);
after upload → `issue.uploaded` (`gh_number`, `url`); 2c → `issue.implement.end`; 2d →
`issue.validate.end` (`attempt`, parsed suite counts — the tracker's `pytest` field carries the headless-suite totals, `mypy` stays `null`; on a parse failure emit with
`null` counts and `data.parse_error` rather than skipping the event); 2e → `issue.commit`; 2g →
`issue.closed`; end of loop → `issue.end` (`attempts`).

**Step 3's failure path is the one that matters.** Emit `issue.failed` (with a classified `reason`:
`test-failure` / `type-error` / `import-error` / `timeout` / `other`) and then `issue.reverted`
**before** `git checkout -- .` runs. After the revert there is no commit, no file and no trace — this
event is the *only* record that the attempt happened, which is the whole reason this system exists.

#### 2h. Log progress

Append to the in-memory execution log: issue ID + title, commit hash, files changed,
validation results, status (success/partial/failed).

### Step 3: Handle failures

If implementation or validation fails for an issue:

1. Do NOT commit broken code
2. Revert changes: `git checkout -- .`
3. Add a comment to the GitHub issue explaining what failed
4. Log the failure
5. Ask the user: continue to next issue (if no dependency), or stop?

### Step 3b: No automatic version bump

**Do NOT bump the version automatically.** Never change the version (VERSION file,
RELEASE.txt, or git tag) without explicit user confirmation. When a phase's issues are
all done, report completion and let the user decide whether/when to release via
`/release-version`.

Version notation `vA.B.C`: `A` = roadmap version (v0…v6), `B` = phase, `C` =
post-release fix. Roadmap phase `vA.B` → release `vA.B.0`. If some issues failed or
were skipped, do NOT release — note in the report that the phase is incomplete.

### Step 4: Generate execution report

After all issues are processed (or on stop), generate `specification/implementation/v{A.B}-execution-report.md`:

```markdown
# Phase v{A.B} -- Execution Report

**Date:** {date}
**Branch:** {branch name}
**Label:** {label}
**Target release:** v{A.B}.00
**Executed by:** Claude Code

## Summary

| Status | Count |
|--------|-------|
| Completed | {n} |
| Failed | {n} |
| Skipped | {n} |
| Remaining | {n} |

## Issues

| # | MYRMEX ID | Title | Phase | Status | Commit | Files | Tests |
|---|----------|-------|-------|--------|--------|-------|-------|
| 1 | MYRMEX-001 | ... | v0.2 | completed | a1b2c3d | 4 | pass |

## Detailed Results

### MYRMEX-001: ...
**Status:** completed · **Commit:** a1b2c3d
**Validation:** [x] tests · [x] determinism · [x] acceptance

## Next Steps
{remaining issues + dependencies}
```

Commit and push the report (`MYRMEX`-style message, with the Co-Authored-By trailer).

## Important Rules

- **Generate every line fresh.** Never `git checkout`/`cherry-pick`/merge code out of git history or any other ref to satisfy an issue — every line is written in-session.
- **One issue at a time.** Never work on multiple issues simultaneously.
- **Dependency order.** Never start an issue whose dependencies are not closed.
- **Clean commits.** Each issue = one commit. No mixing work across issues.
- **No broken code.** Only commit code that passes validation (the headless suite + determinism).
- **Tests ship with the feature.** Use the `MOCK` provider by default so the suite stays deterministic;
  live calls are permitted and opt-in.
- **Sim stays pure data.** `res://sim/` has no `Node`, scene, or network dependency; view/UI only read state; observer commands land at tick boundaries.
- **Determinism is a contract.** Seeded RNG only, id order, fixed tick phase order; never wall-clock, unordered iteration, or unlogged randomness in sim logic. LLM output is untrusted: every program version is validated before apply.
- **Contracts stay stable.** A seam change updates `specification/ARCHITECTURE.md` and its contract test in the same commit.
- **Secrets stay out of the repo.** LLM keys live in local configuration outside the project; never in code, `.tres`, logs, or tests.
- **Ask on ambiguity.** If an issue description is unclear, ask the user rather than guessing.
- **Progress updates.** Print a short status line after each issue completes.
