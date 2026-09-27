---
name: ship-solution
description: Ship the WHOLE solution end-to-end from the already-generated issues files. Takes one selector or a comma-separated LIST of versions/phases/ranges (default: all); the list names TARGETS - missing prerequisite phases are added automatically, de-duplicated, sorted into roadmap dependency order, and already-released phases skipped. Per phase - reconcile-issues, execute-issues-file (no GitHub), review-and-fix-issues, release-version vA.B.0 - timing each phase. HARDEN after each version by default (--no-harden to skip). At the end, generate a detailed execution report (per-phase + per-version + total statistics and timings). A simplified, file-driven, offline sibling of ship-phase.
---

# Skill: Ship Solution

Build the **entire solution end-to-end from the already-generated issues files** — no issue
generation, no GitHub. It walks every version's phases in order and, per phase, reconciles the
pre-written issues against reality, executes them from the file, reviews-and-fixes, and releases —
**timing each phase** — hardens at each version boundary, and finally **generates a detailed execution
report** with statistics and timings summarized **by phase, by version, and in total**.

This is a simplified, offline sibling of `/ship-phase`. The differences (by ship-phase step):

| ship-phase step | here |
|---|---|
| 0. reconcile (inside generate) | **`reconcile-issues`** — review the *pre-generated* issues file and correct drifted issues **in place, with a `⟳ Reconciled` change-mark** |
| 1. generate-issues | **skipped** — the `vA.B-issues.md` files already exist. **Consequence:** a phase with no issues file cannot be built here, where ship-phase would simply generate one (see Step 0.4) |
| 2. upload-issues | **skipped** — no GitHub |
| 3. execute-issues | **`execute-issues-file`** — implement straight from the file (no GitHub, no issue-closing) |
| 4. review-and-fix-issues | **kept** (unchanged) |
| 5. release-version | **kept** (unchanged) |
| end-of-version HARDEN | **same** — by default after every version, `--no-harden` to skip |
| per-version chat report | **replaced** — a single **detailed report** generated after **all** versions |

A **thin orchestrator**: it sequences the sub-skills (`reconcile-issues`, `execute-issues-file`,
`review-and-fix-issues`, `harden-findings`, `release-version`), gates between them, **measures
per-phase execution time**, and writes the final report.

> **This pipeline releases.** Invoking `/ship-solution` opts into automated per-phase releases (real
> tags + pushes) **and** the per-version HARDEN sweep. To build without releasing, use the individual
> skills.

## Usage

```
/ship-solution [<selector>[,<selector>…]] [--no-harden]
```

A **selector** is a version (`vA`), a phase (`vA.B`), or a range (`vA-vB`). Pass **one, or a
comma-separated list of any mix** — the whole list is expanded into a single ordered plan. Omit it
entirely to ship the whole solution.

- `/ship-solution` — ship **the whole solution**: every phase with a `specification/implementation/
  vA.B-issues.md`, in roadmap order, then generate the final report.
- `/ship-solution v4` — version v4 **and its prerequisites** (v0, v1), hardened per version, reported
  at the end.
- `/ship-solution v1-v5` — versions v1 through v5, prerequisites filled in.
- `/ship-solution v0,v4,v6` — a **list of versions**, shipped in roadmap order with the gaps filled.
- `/ship-solution v0.1,v0.3,v1` — a **mixed list**: two individual phases plus a whole version.
- `/ship-solution v4 --no-harden` — no hardening sweeps at any version boundary.

Whitespace around commas is ignored. `--no-harden` applies to **every** version in the plan; there is no
per-version form.

> **The list is a target, not the whole plan.** Missing prerequisites are **added automatically** — the
> roadmap is cumulative, so `/ship-solution v4` plans v0 and v1 as well. Anything already released is
> then skipped, so on a repo built up to v6.2, `/ship-solution v6.3` does exactly one phase's
> work. You name the destination; the skill works out what has to happen to get there.
>
> Unlike `/ship-phase`, this skill **cannot generate a missing issues file** — so a required
> prerequisite that has neither a release tag nor an issues file is a hard stop, not a skip (Step 0.4).

## Instructions

### Step 0: Scope, baseline, plan — and start the clock

0. **Check for an unfinished previous run — before anything else.** If `codegen/runs/current` names a
   run with no terminal event, show what it was (command, start time, last released phase, what it
   was mid-way through) and **ask**: resume it (same `run_id`, same log, emit `run.resumed`) or start a
   new run (close the old with `run.aborted` `reason: "superseded"`, link the new one via `resumes`)?
   Never decide silently — the choice determines whether this version's timings belong to one run or two.
1. **Parse the selector list.** Split the argument on commas and trim whitespace; each element is a
   **version** (`vA`), a **phase** (`vA.B`), or a **range** (`vA-vB`). **No argument → all**
   phases that have an issues file. Record whether `--no-harden` was passed (it applies to the whole
   plan). If any element doesn't resolve to a real roadmap version/phase — a typo, an out-of-range
   `v9`, a reversed range (`v2-v0`) — **name it and ask**; never drop it and ship the rest.
2. **Expand to a phase set.** Read [specification/ROADMAP.md](../../../specification/ROADMAP.md) and resolve every
   selector to individual phases (`### vA.B` headings under `## vA`, in file order): a version → all
   its phases; a range → all phases of the versions it spans; a phase → itself. **De-duplicate.**
3. **Close the set under its dependencies.** The roadmap is cumulative — v4 (the server and clients) cannot be built
   without v0's prototype or v1's full nest. Take the **highest** phase in the set and add
   **every roadmap phase preceding it** that isn't already there. Missing prerequisites are executed,
   not warned about. **Report the added phases** at confirmation, but don't ask permission — they are
   requirements, not scope creep.
4. **Resolve each phase in the closed set to one of three states**, in this order:
   - **Already released** (tag `vA.B.0` exists) → **skip**; the dependency is satisfied. This is what
     keeps the fill cheap: on a repo built to v6.2, `/ship-solution v6.3` still runs one phase.
   - **Not released, has `specification/implementation/vA.B-issues.md`** → **include** in the plan.
   - **Not released, no issues file** → **STOP.** This skill executes from issues files and cannot
     generate one. Name every phase in this state, say plainly that the run cannot proceed because a
     target depends on them, and offer the two real options: run `/generate-issues vA.B` for each (or
     author the files), or use `/ship-phase`, which generates them as step 1. **Never silently drop the
     phase and continue** — the target would then build against code its prerequisite never wrote.

   A partially-done phase (issues/report exist but no tag) is *not* released: it resumes from its
   remaining steps, since the sub-skills are idempotent.
5. **Sort into roadmap order and group by version.** The set is a *set*, never a running order —
   `/ship-solution v4,v0` ships v0 first. This is not cosmetic: each phase reconciles against the
   previous one's real, released code, so running out of roadmap order would reconcile against a
   codebase that doesn't exist yet. **If the resulting order differs from what was typed, say so.**
6. Confirm the working branch (`main`) + a clean tree; establish a **green baseline** (`scripts/test.sh`)
   and **record the baseline test count** (the "before" for statistics); on a repo with no code yet
   the baseline is trivially green. Never start red.
7. **Start the run clock:** capture `RUN_START=$(date +%s)`. Keep a **running stats table** as you go
   (append each phase's row as it finishes to **`.ship-solution-progress.md`** in the repo root — it
   is gitignored — so a long run never loses a measurement).
8. **Size the work** — see **Step 0.5** below. Unlike `/ship-phase`, issue counts here are **counted,
   not estimated**; only duration is projected.
9. **Confirm the plan once** — show the resolved, ordered phase list grouped by version, with the
   dependency fill, any reordering, already-released skips, **and the Step 0.5 sizing**. Then run:
   don't re-confirm each sub-step; pause only for the blockers in the rules.

**Worked example** — `/ship-solution v4.2,v0`, on a repo where v0 is released and every phase
has an issues file:

```
selectors : v4.2 · v0
expanded  : v4.2 | v0.1 … v0.6
filled    : + v1.1 … v1.6, v2.1, v3.1, v4.1     ← prerequisites of v4.2, not named by the user
resolved  : v0.1–v0.6 released → skipped
            v1.1 … v1.6, v2.1, v3.1, v4.1, v4.2 → have issues files → included
ordered   : v1.1 → … → v1.6 → v2.1 → v3.1 → v4.1 → v4.2

PLAN (10 phases to run)
  v1  v1.1 … v1.6    → HARDEN → version row
  v2  v2.1           → HARDEN → version row
  v3  v3.1           → HARDEN → version row
  v4  v4.1, v4.2     → HARDEN → version row

ℹ filled in v1.1–v1.6, v2.1, v3.1 and v4.1: v4.2 cannot build without them.
ℹ reordered: v4.2 was listed first, ships last — roadmap order is required.
ℹ skipped v0.1–v0.6: already released.
```

Had `v1.2` lacked an issues file, the run would **stop at Step 0.4** rather than skipping it — v4.2
depends on it, and this skill cannot generate the file.

### Step 0.5: SIZE the work — counted here, not estimated

`/ship-phase` has to *estimate* issue counts because `generate-issues` has not run yet. **This skill
does not.** Step 0.4 already established that every planned phase has a
`specification/implementation/vA.B-issues.md` — otherwise the run stopped — so the issues exist and can simply
be **counted**.

1. **Count issues per phase** from each file's Issues Summary Table, and read each issue's **Size**
   (S/M/L) from the same row. Convert to points (S=1, M=3, L=5).
2. **Estimate duration only.** Points × observed mean seconds-per-point from previous runs if any
   exist; otherwise state the assumed rate explicitly so the projection is auditable.
3. Emit **`run.estimate`** with `source: "counted"`, carrying per-phase counts, points and the
   duration projection.

> **The burn-down for a `/ship-solution` run therefore has no scope-uncertainty band** — total work is
> known at t=0 and only the *time* axis is projected. That is a real difference from `/ship-phase`, not
> an omission: reconcile-issues may still mark an issue moot, but it never invents new ones.

### Step 1: For each version → for each phase — timed, gated

Run phases **strictly in sequence** — phase N+1 only after N is **released** (so N+1's issues
reconcile against N's real, fixed, released code). Invoke each sub-skill via the **Skill tool**.

**At the version's first phase, stamp `VERSION_START=$(date +%s)`.** For **each phase**:

- **Stamp `P_START=$(date +%s)`** (before reconcile).
1. **`reconcile-issues vA.B`** — correct the pre-generated issues **in place with a dated `⟳
   Reconciled` mark**; commit the file. (No code implemented here.)
2. **`execute-issues-file vA.B`** — implement each issue from the reconciled file in dependency order
   → validate (`scripts/test.sh` (the headless test suite), **LLM mocked**) → commit (one issue = one commit) → push;
   write `vA.B-execution-report.md`. **No GitHub.**
3. **`review-and-fix-issues vA.B`** — the ranked review doc + **fix-now** fixes only (with regression
   tests), recorded in that doc.
4. **`release-version vA.B.0`** — bump + tag `vA.B.0` + push.
- **Stamp `P_END=$(date +%s)`** (after release). **Record the phase's row:** duration
  `P_END − P_START`, plus the stats collected below.

**Per-phase statistics to record** (for the final report):
- **duration** (mm:ss);
- **reconcile:** # issues corrected / marked moot / untouched;
- **execute:** # issues implemented, commit count (or hash range), **tests before → after**;
- **review:** # findings fix-now (fixed) / deferred (by severity);
- **release tag.**

Gate the hand-offs: reconcile → execute → review → release; **release only after the review's fix-now
items are committed and the suite is green**; the **next phase only after this one is released**.
Do **not** report to chat between phases.

**Every phase boundary ends pushed and clean.** Before starting phase N+1, verify `git status` is
clean and there are **no unpushed commits** — `git push` if there are. The sub-skills each push their
own work, so this is a check, not new work; it exists because this skill stops on failure, and a stop
must never strand a phase's work locally.

### Step 2: End of every version — HARDEN (default; `--no-harden` to skip), then close the version clock

When a version's last phase is released, run the sweep. **This is the default** — invoking
`/ship-solution` is the consent, exactly as it is for the automated per-phase releases the same
command performs; the Step 0 plan already included it, so don't ask. **With `--no-harden`, skip it
entirely**: the deferred HIGH/MEDIUM findings stay in their documented homes, and the version row records
the sweep as skipped with those findings listed as still-outstanding.

Otherwise invoke **`harden-findings vA --release`** — it fixes every still-unfixed 🔴
HIGH / 🟠 MEDIUM finding from the run's code-review reports (each with a regression test), updates those
reports, and ships a **`C` patch** on the version's latest phase (🟡 LOW stays deferred; the escape
hatch still applies). **Stamp `VERSION_END=$(date +%s)`** and record the version's row: total duration
(`VERSION_END − VERSION_START`), phases, issues, commits, HARDEN findings fixed + patch tag. Then
continue. **No per-version chat report.**

### Step 3: Generate the final execution report (statistics + timings)

Only after the **whole scope** is shipped (or the run stops), stamp `RUN_END=$(date +%s)` and
**generate `specification/implementation/ship-solution-report.md`** — a detailed report with **timings and
statistics summarized by phase, by version, and in total**. Commit + push it, and print its summary to
chat. Structure:

```markdown
# Ship-Solution Execution Report — <date>

## Total
- Wall-clock: <Hh Mm Ss>  (RUN_END − RUN_START)
- Versions: <n> · Phases: <m> · Issues executed: <k> · Commits: <c>
- Releases: <all vA.B.C tags>
- Findings: fix-now fixed <a> · hardened HIGH/MEDIUM <b> · LOW deferred <c> · held <d>
  (with `--no-harden`: hardened 0, and the outstanding HIGH/MEDIUM count with their homes)
- Reconcile: issues corrected <x> · moot <y> · untouched <z>
- Suite: <baseline> → <final> tests passing · deterministic · zero paid calls

## By version
| Version | Phases | Duration | Issues | Commits | Reconciled (corr/moot) | Fix-now | Hardened | Release tags | HARDEN patch |
|-------|----------|----------|--------|---------|------------------------|---------|----------|--------------|--------------|
| vA    | …        | mm:ss    | …      | …       | …                      | …       | …        | …            | …            |

## By phase
| Phase | Duration | Issues | Commits | Tests (before→after) | Reconcile (corr/moot/kept) | Review (fix-now/deferred) | Release tag |
|---------|----------|--------|---------|----------------------|----------------------------|---------------------------|-------------|
| vA.B    | mm:ss    | …      | …       | … → …                | …                          | …                         | vA.B.0    |

## Timings
- Fastest / slowest phase (with durations); average per phase; per-version totals.

## Notes
- Anything held via an escape hatch, anything that stopped early (with what remains), the reconcile
  highlights (notable issue corrections).
```

Durations: compute from the epoch stamps (`end − start`); render `mm:ss` per phase, `Hh Mm` for
versions/total. Every number must trace to the run (execution reports, review docs, release tags).

## Important Rules

- **File-driven, no GitHub.** Issues come from `specification/implementation/*-issues.md`; nothing is uploaded to
  or closed on GitHub. A required phase with **no issues file cannot be built here** — that is a hard
  stop (Step 0.4), never a silent skip, because this skill cannot generate one.
- **Reconcile, don't regenerate.** Step 1 corrects the pre-generated issues in place (with `⟳
  Reconciled` marks), the file-driven analogue of ship-phase's reconcile.
- **Time every phase.** Stamp `date +%s` at each phase's start/end (and each version's start/end and
  the run's start/end); persist rows as you go so no measurement is lost.
- **Every phase boundary ends pushed and clean** — no unpushed commits, no dirty tree, before the
  next phase starts.
- **Release per PHASE**, after its fix-now items are fixed; **next phase only after the previous is
  released**. Never batch phases; never release mid-phase.
- **The plan is roadmap-ordered and dependency-complete.** A selector list is a *set* of target
  phases, not a running order and not the full scope. De-duplicate, **add every missing phase
  preceding the highest selected**, sort into roadmap order, then drop the already-released. The fill is
  reported but not asked about — those phases are requirements.
- **HARDEN runs at each version boundary BY DEFAULT** and ships a `C` patch; only LOW stays deferred.
  Skipped only with `--no-harden`, and then the outstanding HIGH/MEDIUM findings are recorded as such.
  A fix that can't land cleanly is **held** by `harden-findings`' escape hatch, not forced.
- **One report, at the end** — the generated `ship-solution-report.md` (statistics + timings by
  phase/version/total) plus its chat summary. No per-phase or per-version chat report.
- **Sequential and gated; stop on failure.** Any sub-skill failure or a red suite halts the
  pipeline; report what completed and what remains, and still generate the report for the phases that
  shipped. Never release a phase whose suite isn't green.
- **Every fix ships a regression test; the LLM is mocked by default** (live calls opt-in); the suite stays green
  and deterministic.
- **Delegate, never duplicate.** This skill sequences the sub-skills, gates, times, and reports — no
  other logic. Each sub-skill keeps its discipline (one issue = one commit, seam changes carry
  `specification/ARCHITECTURE.md` + contract test, unprefixed `vA.B.C` tags, every line generated fresh).
- **Surface real decisions** — a missing issues file for a required phase, an unresolvable selector, a
  tag collision, a held HARDEN finding, an ambiguous reconcile, or any execution/validation failure.
  Routine plan confirmations run straight through.
