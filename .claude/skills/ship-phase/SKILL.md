---
name: ship-phase
description: Full delivery pipeline over the roadmap. Takes one selector or a comma-separated LIST of versions/phases/ranges (e.g. v0,v4.2,v5-v6). The list names TARGETS - missing prerequisite phases are added automatically, the set is de-duplicated, sorted into roadmap dependency order, and already-released phases are skipped. For each version (vA) run its phases (vA.B) in order - RECONCILE with the real implementation, generate-issues, upload-issues, execute-issues, review-and-fix-issues, release-version vA.B.0 (release per PHASE). At the END of every version a HARDEN sweep runs BY DEFAULT (opt out with --no-harden) fixing the deferred HIGH/MEDIUM findings, then the version is reported to chat. Gated; stops on failure; surfaces real decisions.
---

# Skill: Ship Version — the full delivery pipeline

Drive the entire SDLC loop over the roadmap: **versions contain phases; each phase is released;
the next phase is generated only after the previous one is implemented and fixed** — reconciled
against the real (post-fix) implementation. Hardening of deferred findings runs **by default at every
version boundary** — pass `--no-harden` to skip it.

> **Terminology (per [ROADMAP.md](../../../specification/ROADMAP.md)):** a **version** is a top-level
> roadmap block `vA` (v0 … v6); a **phase** is a `vA.B` block inside it, released as `vA.B.0`. The
> sub-skills use the same words — the GitHub label is `vA.B::phase` and the invocation is
> `generate-issues <vA.B>` — so versions contain phases, consistently throughout.

**The loop:**

```
PLAN = selectors → phases → de-duplicated → + missing prerequisites → sorted into
       roadmap dependency order → minus already-released → grouped by version

for each VERSION vA in PLAN (in roadmap order):
    for each PHASE vA.B of that version in PLAN (in order):
        0. RECONCILE   — ground this phase in the real implementation + all prior fixes
        1. generate-issues vA.B
        2. upload-issues @specification/implementation/vA.B-issues.md
        3. execute-issues vA.B::phase        (implement → validate → commit → push → close)
        4. review-and-fix-issues vA.B        (review → ranked doc → fix-now fixes → same doc)
        5. release-version vA.B.0           ← RELEASE PER PHASE (tag vA.B.0)
    → END OF VERSION: HARDEN (skill: harden-findings) — BY DEFAULT (skipped only with --no-harden)
    → REPORT the version to chat
→ next version; after the whole scope: overall summary to chat
```

This skill is a **thin orchestrator** — it sequences the sub-skills, adds the reconcile gate and the
end-of-version hardening sweep, and releases per phase; each sub-skill keeps its discipline.

> **This pipeline releases.** Invoking `/ship-phase` is the explicit opt-in to the automated
> per-phase releases (real tags + pushes) **and** the per-version HARDEN sweep. `release-version`'s own
> rules still hold — it never downgrades and confirms the changelog. To build without releasing, use
> the individual skills.

## Usage

```
/ship-phase <selector>[,<selector>…] [--no-harden]
```

A **selector** is a version (`vA`), a phase (`vA.B`), or a range (`vA-vB`). Pass **one or a
comma-separated list of any mix** — the whole list is expanded into a single ordered plan.

- `/ship-phase v1` — ship **version v1**: every phase in it (v1.1 → … → v1.6), each through
  its five steps incl. its own release; at the version's end the HARDEN sweep runs; then the version
  report to chat.
- `/ship-phase v1 --no-harden` — same, but the end-of-version HARDEN sweep is **skipped**; the deferred
  HIGH/MEDIUM findings stay in their documented homes.
- `/ship-phase v1.2` — ship the single **phase v1.2** (steps 0–5, incl. its release), then
  HARDEN v1 at the version boundary.
- `/ship-phase v1-v2` — ship version v1, then version v2 (each hardened at its boundary), then an
  overall summary.
- `/ship-phase v0,v4,v6` — a **list of versions**, shipped in roadmap order.
- `/ship-phase v0.1,v0.3,v1` — a **mixed list**: two individual phases plus a whole version.
- `/ship-phase v0-v1,v5.1 --no-harden` — a range plus a single phase, with no hardening sweeps.

Whitespace around commas is ignored, so `v0, v4` works. `--no-harden` applies to **every** version in
the plan; there is no per-version form.

> **The list is a target, not the whole plan.** Missing prerequisites are **added automatically** — the
> roadmap is cumulative, so `/ship-phase v4` plans v0–v3 as well, and `/ship-phase v0,v4` fills
> in the v1–v3 you left out. Anything already released is then skipped, so on a repo built up to v6.2,
> `/ship-phase v6.3` still does exactly one phase's work. You name the destination; the skill works
> out what has to happen to get there.

## Instructions

### Step 0: Scope, baseline, and the version → phase plan

0. **Check for an unfinished previous run — before anything else.** If `codegen/runs/current` names a
   run whose log has no terminal event (`run.end` / `run.aborted`), that run stopped without closing.
   **Show what it was** — its command, when it started, the last phase it released, and what it was
   in the middle of — then **ask which this is**:
   - **Resume it** → keep the same `run_id` and keep appending to the same log; emit `run.resumed`.
     The plan is recomputed normally, so already-released phases skip themselves and the run picks up
     where it stopped. Timings stay attributed to one run, with the idle gap excluded (see below).
   - **A new run** → close the old one with `run.aborted` (`reason: "superseded"`), then start fresh
     with `resumes: <old-run-id>` on `run.start` so the two stay linked without being merged.

   Never decide this silently. Resuming when the user meant a fresh run corrupts that run's timings;
   starting fresh when they meant resume splits one version across two runs and makes "how long did v0
   take" unanswerable. This is exactly the kind of genuine decision this skill pauses for.
1. **Parse the selector list.** Split the argument on commas and trim whitespace. Each element is a
   **version** (`vA`), a **phase** (`vA.B`), or a **range** (`vA-vB`); a single element is just a
   list of one. Record whether `--no-harden` was passed (it applies to the whole plan).
2. **Expand to a phase set.** Read [specification/ROADMAP.md](../../../specification/ROADMAP.md) and resolve every
   selector down to individual phases (`### vA.B` headings under `## vA`, in file order):
   a version → all its phases; a range → all phases of all versions it spans; a phase → itself.
   **De-duplicate** — overlapping selectors (`v0,v0.2`) contribute each phase once.
3. **Close the set under its dependencies — add every phase the plan needs but the user didn't
   name.** The roadmap is strictly cumulative: v4 (the server and clients) cannot be built without v0's
   prototype or v1's full nest. So take the **highest** phase in the set and add **every roadmap phase
   that precedes it** and isn't already there. Missing prerequisites are executed, not warned about.
   - `/ship-phase v4` → plans v0.1 … v4.3, not just v4's three phases.
   - `/ship-phase v0,v4` → the omitted v1.1–v1.6, v2.1 and v3.1 are filled in.
   - `/ship-phase v6.3` → plans the whole roadmap up to and including v6.3.

   This is safe precisely because of step 7: any filled-in phase that is **already shipped** (its
   release tag exists) is skipped, so on a repo that is built up to v6.2, `/ship-phase v6.3` still
   does exactly one phase's work. On an empty repo the same command correctly builds everything.
   **Report the added phases** at confirmation — the user gets more than they asked for and should
   see it — but do not ask permission for them; they are requirements, not scope creep.
4. **Sort into roadmap order and group by version.** The set is a *set*, never a running order.
   `/ship-phase v4,v0` ships v0 first. This is not cosmetic: the pipeline's premise is that each
   phase is generated against the previous one's real, released code, so executing out of roadmap
   order would reconcile against a codebase that doesn't exist yet. **If the resulting order differs
   from what was typed, say so** at confirmation. Group the phases back under their versions for the
   per-version HARDEN and reporting.
5. **Reject nothing silently.** If a selector doesn't resolve to a real roadmap version/phase — a typo,
   an out-of-range `v9`, a reversed range (`v2-v0`) — name the offending element and ask. Never drop
   an unparseable element and proceed with the rest.
6. Confirm we are on the working branch (`main`) and the tree is clean; establish a **green baseline**
   (`scripts/test.sh`); on a repo with no code yet (before v0.1 lands) the baseline is trivially
   green — note that and continue. Never start on a red suite — fix a clear flake first or surface it.
7. **Skip already-shipped phases** (release tag `vA.B.0` exists). This is what keeps step 3's
   dependency fill cheap: prerequisites that are already built cost nothing. A phase partially done
   (issues/report exist but no tag) resumes from its remaining steps — each sub-skill is idempotent
   (`generate` asks overwrite, `upload` dedupes, `execute` skips closed issues, `release` refuses a
   downgrade).
8. **Estimate the work** — see **Step 0.5** below. Produces an approximate issue count, size mix and
   duration per planned phase, so progress has something to be measured against from minute one.
9. **Confirm the plan once** — show it as the resolved, ordered phase list grouped by version, with the
   dependency fill, any reordering, already-shipped skips, **and the Step 0.5 estimate**. Then run: do
   not re-confirm before each sub-step; pause only for the genuine blockers in the rules below.

**Worked example** — `/ship-phase v4.2,v0`, on a repo where v0 is already released:

```
selectors : v4.2 · v0
expanded  : v4.2 | v0.1 … v0.6
de-duped  : (no overlap)
filled    : + v1.1 … v1.6, v2.1, v3.1, v4.1     ← prerequisites of v4.2, not named by the user
ordered   : v0.1 → … → v0.6 → v1.1 → … → v1.6 → v2.1 → v3.1 → v4.1 → v4.2
shipped?  : v0.1–v0.6 tagged already → skipped

PLAN (10 phases to run)
  v1  v1.1 … v1.6    → HARDEN → report
  v2  v2.1           → HARDEN → report
  v3  v3.1           → HARDEN → report
  v4  v4.1, v4.2     → HARDEN → report

ℹ filled in v1.1–v1.6, v2.1, v3.1 and v4.1: v4.2 cannot build without them.
ℹ reordered: v4.2 was listed first, ships last — roadmap order is required.
ℹ skipped v0.1–v0.6: already released.
```

Note what the fill did **not** cost: v0 was named by the user but is already shipped, so it drops out;
v1–v3 and v4.1 were never named but are genuinely missing, so they run. The plan is the *work actually
required*, not the literal argument.

### Step 0.5: ESTIMATE the work — before anything is generated

Nothing in the plan yet says *how big* it is. `generate-issues` has not run, so no phase's issue count
exists. Without an estimate the burn-down has no total, the ideal line has no endpoint, and the ETA is
blank until the first phase finishes — which on a five-phase run is a long time to show nothing.

So: **estimate now, from the roadmap alone.** For each phase in the plan (skipping already-released
ones), read its `### vA.B` section and estimate three things:

| Estimate | How |
|---|---|
| **Issue count** | Anchor on the phase's **Tasks** list — `generate-issues` turns tasks into coherent slices, so a phase with N tasks tends toward N issues. Clamp to the 3–7 band that skill produces. Give a low/high, not a point. |
| **Size mix** | From the Tasks + DoD: work touching a seam (`StateView`, the policy schema, `StrategyRunner`, the save format) skews **M/L**; additive work inside an existing module skews **S/M**. Convert to points (S=1, M=3, L=5) — the burn-down is size-weighted, so counts alone are not enough. |
| **Duration** | Points × the observed mean seconds-per-point from previous runs if any exist; otherwise state the assumed rate explicitly so the number is auditable rather than magic. |

Emit **`run.estimate`** carrying per-phase and total figures, then show them in the Step 0
item 9 confirmation, as a range.

> **⚠️ The estimate must never be given to `generate-issues`.** It is a projection for the burn-down and
> the ETA — not a target, not a quota, and not an input to decomposition. If the estimate reached the
> decomposer, it would become self-fulfilling: the run would produce roughly the predicted number of
> issues and the comparison would measure nothing but its own suggestion. **The estimate and the actual
> are expected to differ, and that difference is a measurement worth having** — it is how well the
> roadmap predicts its own decomposition. Keep them independent so the number stays honest.

When a phase is later decomposed, the difference is recorded automatically (`version.decomposed`
carries the real issue list; the reducer compares it to this estimate). A consistent bias in one
direction is a finding about the roadmap or the decomposer, not noise to be tuned away.

### Step 1: For each version → for each phase — the five steps, gated

Run the phases **strictly in sequence** — phase N+1 starts only after phase N is **released**
(implemented, reviewed, fixed, tagged). That sequencing is the point: the next phase's issues are
generated against the previous phase's *real, fixed* implementation. Invoke each sub-skill via the
**Skill tool** (it loads that skill's instructions; follow them fully).

**0. RECONCILE** — the first act of every phase's cycle, carried out **inside `generate-issues`
   (its Step 0.5)**: before decomposing `vA.B`, read (a) the **real current code** of the components
   it touches, (b) prior `specification/implementation/*-execution-report.md`, and (c) prior
   `specification/implementation/*code-review*.md` — especially their **"Fixes applied"** and **"Architecture
   impact"** notes from review/harden work. Where fixes drifted the code from `ARCHITECTURE.md`, the
   implementation is ground truth; doc corrections ride along in the seam-touching issue. This is
   where "changes in architecture after fixes" enter the next phase's issues.
1. **`generate-issues vA.B`** → `specification/implementation/vA.B-issues.md` (reconciled, per step 0).
2. **`upload-issues @specification/implementation/vA.B-issues.md`** → the GitHub issues + labels + deps +
   `vA.B-github-report.md`.
3. **`execute-issues vA.B::phase`** → implement → validate → commit → **push** → close each issue in
   dependency order (statuses change; one issue = one commit), then `vA.B-execution-report.md`.
4. **`review-and-fix-issues vA.B`** → code review, the criticality-ranked recommendations doc, the
   **fix-now** fixes only (with regression tests, LLM mocked), results recorded **in that same doc**
   (incl. "Architecture impact" notes). Deferred findings stay deferred — they are the HARDEN sweep's
   input, at the end of the version, if the user opts in.
5. **`release-version vA.B.0`** → bump `VERSION`/`RELEASE.txt`/`project.godot`, tag `vA.B.0`, and
   push. **Release per phase.**

Gate the hand-offs: upload only after generate wrote the file; execute only after the issues exist;
review only after execute closed the issues with a green report; **release only after the review's
fix-now items are committed and the suite is green**; the **next phase only after this one is
released**.

**Every phase boundary ends pushed and clean.** Before starting phase N+1, verify `git status` is
clean and the branch has **no unpushed commits** — `git push` if it does. Each sub-skill already pushes
its own work (one issue = one commit = one push; review pushes each fix; `release-version` pushes the
branch and its tag), so this is a check rather than new work — but it is the check that makes the
guarantee real. This skill **stops on failure by design**, so halting mid-phase is a normal outcome,
not an edge case: a stop must never strand a phase's work on one machine.

### Step 1.5: TRACKING — emit as you go

Emit one event per transition: `python3 -m tracker.emit <type> --emitter skill:ship-phase --scope
k=v,... [--status ok|fail|skip] [--data '{...}']`. It never raises and never blocks, so a tracking
failure cannot fail a step (architecture §5.2). Sites: Step 0 → `run.start` (plan, baseline, git), or
`run.resumed` when resuming; Step 0.5 → `run.estimate`; per version → `phase.start`/`phase.end`; per
phase → `version.start`/`version.end`/`version.skipped`; per sub-skill → `step.start`/`step.end`; a
blocked gate → `gate.blocked`; the end → `run.end`. (The event names keep the tracker's original
schema, which named the two levels the other way around — emit them exactly as spelled here.) `--no-harden` still emits `harden.skipped` — a
missing event and a skipped sweep must never look alike.

### Step 2: END OF VERSION — HARDEN (default; `--no-harden` to skip)

When the version's last phase is released, sweep the deferred 🔴 HIGH / 🟠 MEDIUM findings accumulated
in the run's code-review reports. **This runs by default** — invoking `/ship-phase` is the consent,
exactly as it is for the automated per-phase releases the same command performs.

- **No flag** → run the sweep. Do not ask; the plan confirmed at Step 0 already included it.
- **`--no-harden` was passed** → skip it entirely. The deferred HIGH/MEDIUM findings stay in their
  documented homes and are listed as still-outstanding in the version report.

> Leaving hardening on by default means a version does not close with known HIGH-severity findings
> sitting unfixed in its own review docs. The escape hatch inside `harden-findings` — a fix that can't
> land cleanly is held with a reason rather than forced — is what keeps that safe.

**Delegate the sweep to the dedicated skill:** invoke **`harden-findings vA --release`** via the
Skill tool and follow its instructions fully. That skill collects the run's
code-review reports, fixes every still-unfixed 🔴 HIGH / 🟠 MEDIUM finding (🟡 LOW stays deferred) —
each with a regression test, validated green, one focused commit — updates the reports in place
("Fixes applied" + "Architecture impact", which the next version's RECONCILE reads), and, because the
version's phases are already released, ships the result as a **`C` patch release** on the version's
latest phase (e.g. `v1.3.1`). Its escape hatch (a fix that can't land safely is held with a
reason and surfaced) applies unchanged.

### Step 3: REPORT the version to chat

After the version (and its HARDEN sweep, unless `--no-harden`), **report the version to chat** (not a file):
- **Per phase:** MYRMEX id range → GitHub #s, execution commit range + test status, review
  finding counts (**fixed-now / deferred**, with homes), any **Architecture impact** deltas, and the
  release tag.
- **HARDEN outcome:** which findings were fixed and the patch tag — or, with `--no-harden`, that the
  sweep was skipped, plus the still-outstanding HIGH/MEDIUM findings and their homes. Findings **held**
  by the escape hatch are listed either way, with the reason.
- **Version rollup:** what the version delivered against its roadmap goal.

Then continue to the next version. After the whole scope, add a short **overall summary** (versions
shipped, phases skipped as already-released, anything stopped early and what remains, what's next).

## Important Rules

- **Release per PHASE (`vA.B.0`)** — after that phase is built, reviewed, and its fix-now items
  fixed. Never batch several phases into one release; never release mid-phase.
- **HARDEN is end-of-version and runs BY DEFAULT.** Invoking `/ship-phase` is the consent. It is skipped
  only when `--no-harden` was passed — then the deferred HIGH/MEDIUM findings stay in their documented
  homes and are surfaced as outstanding in the version report. When it runs and lands fixes, ship them as
  a `C` patch release on the version's latest phase. A fix that can't land cleanly is **held** by
  `harden-findings`' escape hatch, not forced.
- **Every phase boundary ends pushed and clean.** No unpushed commits, no dirty tree, before the
  next phase starts. This skill stops on failure by design, so a stop must never leave a phase's
  work on one machine only.
- **Next phase only after the previous is released.** The strict sequencing is what makes the
  RECONCILE step meaningful: phase N+1's issues are generated against phase N's real, fixed code.
- **Reconciliation is step 0 of every phase** (via `generate-issues` Step 0.5): real code + execution
  reports + review docs' "Fixes applied"/"Architecture impact" are the input to the next phase's
  issues; `ARCHITECTURE.md` corrections ride along in seam-touching issues.
- **Sequential and gated.** Each step's output is the next step's input. Never start a step whose
  predecessor didn't finish cleanly; never interleave two phases' pipelines.
- **Stop on failure — do not paper over it.** If any sub-skill fails, or any fix hits a red
  suite, halt, report what completed and what remains, and let the user decide. Never release
  a phase whose suite isn't green.
- **Every fix ships a regression test**, the LLM is mocked by default (live calls opt-in), and the suite stays
  green and deterministic.
- **Surface real decisions.** Pause for an **ID/tag collision**, an **overwrite/append** prompt, a
  **held** HARDEN finding, or any execution/validation failure. Routine plan confirmations run straight
  through — and the HARDEN sweep is no longer one of them, since the Step 0 plan already covered it.
- **Delegate, never duplicate.** This skill only sequences the sub-skills (`generate-issues`,
  `upload-issues`, `execute-issues`, `review-and-fix-issues`, `harden-findings`, `release-version`)
  and adds the gating; no logic of its own. Each sub-skill keeps its discipline — one issue = one
  commit, seam changes carry `specification/ARCHITECTURE.md` + contract test, IDs stay in this branch's
  `MYRMEX-###` namespace, releases use unprefixed `vA.B.C` tags, every line generated fresh.
- **Ask on a bad target.** If **any** element of the selector list doesn't resolve to a real roadmap
  version/phase, name that element and ask — never silently drop it and ship the rest.
- **The plan is roadmap-ordered and dependency-complete, always.** A selector list is a *set* of target
  phases, not a running order and not the full scope. De-duplicate it, **add every missing phase
  that precedes the highest one selected**, sort into roadmap order, then drop the already-shipped.
  Surface the fill, the reordering, and the skips at confirmation — but the fill is not optional and is
  not asked about: those phases are requirements. Honoring a user-supplied order, or executing a plan
  with dependency holes, would break the reconcile premise that each phase builds on the last one's
  real released code.
