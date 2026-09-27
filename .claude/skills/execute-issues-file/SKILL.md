---
name: execute-issues-file
description: Execute one version's issues directly from its local specification/implementation/vA.B-issues.md file (no GitHub). Implement -> validate -> commit -> push each issue in dependency order, then write an execution report. The offline, file-driven counterpart of execute-issues.
---

# Skill: Execute Issues From File

Execute the issues for one version **straight from its already-generated issues file** —
`specification/implementation/vA.B-issues.md` — with **no GitHub involvement** (no upload, no issue lookup,
no closing). Implement, validate, commit, and push each issue in dependency order, then write an
execution report.

This is the offline counterpart of `execute-issues`: same implementation discipline, but the issue
list comes from the local markdown file instead of `gh issue list`, and there are no GitHub issues to
close.

## Usage

```
/execute-issues-file <vA.B | path-to-issues-file> [--issue MYRMEX-###] [--dry-run]
```

- `/execute-issues-file v1.1` → executes `specification/implementation/v1.1-issues.md`
- `/execute-issues-file @specification/implementation/v4.2-issues.md`
- `--issue MYRMEX-###` → only that issue (its file-listed deps must already be committed)
- `--dry-run` → print the execution plan without making changes

> [!IMPORTANT]
> **Generate every line fresh.** You must **NEVER** `git checkout`/`cherry-pick`/merge code from
> another branch, ref, repository, or a previous run to satisfy an issue. The generated run is the point.

## Instructions

### Step 0: Verify prerequisites & read the file

1. Confirm we are on the working branch (`main`) and the tree is clean (`git status`).
2. Resolve the target to `specification/implementation/vA.B-issues.md` and **read it** — the Issues Summary
   Table (IDs, titles, size, area, dependencies), the Dependency Tree, and each detailed
   `### MYRMEX-### …` section. **No `gh` is used.**
3. Read [specification/ROADMAP.md](../../../specification/ROADMAP.md) for the version goal + the `vA.B` DoD/Tests,
   [specification/ARCHITECTURE.md](../../../specification/ARCHITECTURE.md) for the contracts, and
   [specification/VISION.md](../../../specification/VISION.md) for the product vision and scope.
4. Establish a **green baseline** (`scripts/test.sh` (the headless test suite)) so a later failure is attributable.

### Step 1: Build the execution queue (from the file)

- Parse the MYRMEX-### IDs + titles from the file's summary table; order them by the file's
  **Dependency Tree** (issues with no unmet dependency first).
- **Skip issues already implemented** — an issue whose ID already appears in a prior commit
  (`git log --grep "MYRMEX-###:"`) is done; skip it (resumability).
- With `--issue MYRMEX-###`, execute only that one (verify its file-listed deps are already committed).
- Show the ordered plan and proceed (stop here if `--dry-run`).

### Step 2: Execute each issue (loop, in dependency order)

For each issue:

1. **Announce:** `--- Starting MYRMEX-###: {title} ---`.
2. **Read** its detailed section from the issues file (What needs to be done / Acceptance criteria).
3. **Implement** per `CLAUDE.md` + `specification/ARCHITECTURE.md`, routed by component
   ([ARCHITECTURE.md](../../../specification/ARCHITECTURE.md) §Components): `res://sim/` (pure data,
   deterministic, no `Node`), `res://view/` + `res://ui/` (read sim state only; observer commands at
   tick boundaries), `res://llm/` (providers behind the seam; `MOCK` in tests; the model never controls
   a myrmek), `res://data/` (defaults as `.tres`). A **seam change** (tick phase order, `StateView`,
   policy schema, `StrategyRunner`, task shape, provider interface, save format) updates
   `specification/ARCHITECTURE.md` **and** its contract test in the **same** commit. Prototype-first
   (don't pull later phases in early); terminology: myrmek/nest.
4. **Validate:** `scripts/test.sh` (unit + contract + headless integration where relevant), plus the
   determinism check when `res://sim/` changed — **the LLM provider is `MOCK` by default; a live model
   call is permitted but opt-in.** Walk each acceptance criterion against the phase DoD/Tests in
   `specification/ROADMAP.md`. Record pass/fail.
5. **Commit** (one issue = one commit; only code that passes validation):
   ```bash
   git commit -m "$(cat <<'EOF'
   MYRMEX-###: {title}

   {1-2 sentence summary of what was implemented}

   Co-Authored-By: <the running model's trailer> <noreply@anthropic.com>
   EOF
   )"
   ```
   (No `Closes #…` line — there is no GitHub issue.)
6. **Push:** `git push`.
7. **Log** the issue ID + title, commit hash, files, validation result, status.

### Step 3: Handle failures

If implementation or validation fails: do **not** commit broken code; `git checkout -- .` to revert;
log the failure; then ask the user — continue to the next issue (if nothing depends on the failed one)
or stop.

### Step 3b: No automatic version bump

Do **not** change the version (VERSION/RELEASE.txt/tag) here — that is `/release-version`, on explicit
confirmation. If any issue failed or was skipped, do **not** treat the version as complete.

### Step 4: Write the execution report

Write `specification/implementation/vA.B-execution-report.md`: a summary table (completed/failed/skipped),
a per-issue table (MYRMEX ID · title · status · commit · files · tests), detailed results with the
validation checklist, and next steps. Commit + push it (a `MYRMEX`/`docs` message with the trailer).
(No GitHub mapping section — this run never touched GitHub.)

## Important Rules

- **File-driven, no GitHub.** The issue list, details, and dependency order come from the local
  `*-issues.md` file. Never `gh issue list`/`create`/`close`. No `vA.B-github-report.md` is written.
- **Generate every line fresh** — never recover code from git history or another ref.
- **One issue = one commit.** Never mix work across IDs; never work on two issues at once.
- **Dependency order.** Never start an issue whose file-listed dependencies aren't committed.
- **No broken code.** Only commit what passes `scripts/test.sh` (the headless test suite).
- **Tests ship with the feature; the LLM provider is `MOCK` by default** — no paid API call in tests/validation.
- **Sim stays pure data and deterministic**; view/UI only read state; **contracts stay stable**
  (seam change → `specification/ARCHITECTURE.md` + contract test in the same commit);
  **secrets stay out of the repo** (LLM keys in local config outside the project).
- **Ask on ambiguity.** If an issue's scope is unclear, ask rather than guess.
- **Progress updates.** Print a short status line after each issue.
