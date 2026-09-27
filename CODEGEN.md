# Myrmex — the SDLC pipeline

Myrmex is built from its specification by a set of SDLC skills, and every build run is tracked and
observable. The durable assets are the three specs in `specification/` (VISION, ARCHITECTURE,
ROADMAP), the skills in `.claude/skills/`, and the tracker in `codegen/`; the application code is
their output. Unlike the agent-arena-sandbox this pipeline was adapted from, **the application here
is the product**, not a disposable fixture — but the same cycle (generate → observe → reset →
regenerate) remains available for experiments.

## What's here

```
specification/     the specs the skills build from
  VISION.md            what and why: mission, principles, non-goals, glossary
  ARCHITECTURE.md      how: components, models, contracts, testing, open questions
  ROADMAP.md           when: versions v0–v6, phases vA.B with Goal/Tasks/DoD/Tests
  implementation/      the skills' output: issues files, execution reports, code reviews
  history/             the retired initial concept (frozen)

.claude/skills/    the eleven SDLC skills
  generate-issues · upload-issues · execute-issues · execute-issues-file
  reconcile-issues · review-and-fix-issues · harden-findings · release-version
  reset-generated                   ← clears a run's output, from the run's own log
  ship-phase · ship-solution        ← the two orchestrators

codegen/           the run tracker: hooks + event log + dashboard (see codegen/README.md)
```

## The two workflows

Not to be mixed within one phase (`vA.B`):

- **A. GitHub-driven — `/ship-phase <selectors>`.** Per phase: reconcile against the real code →
  `generate-issues` → `upload-issues` (real GitHub issues) → `execute-issues` (implement → validate →
  commit → push → close, one issue = one commit) → `review-and-fix-issues` → `release-version vA.B.0`.
  A HARDEN sweep of deferred HIGH/MEDIUM findings runs at every version (`vA`) boundary by default
  (`--no-harden` to skip). Needs an authenticated `gh`.
- **B. File-driven, offline — `/ship-solution [selectors]`.** Executes from already-generated
  `specification/implementation/vA.B-issues.md` files: `reconcile-issues` → `execute-issues-file`
  (no GitHub) → `review-and-fix-issues` → `release-version`. It cannot generate a missing issues
  file — that is a hard stop.

Rules that hold everywhere: issue ids are **`MYRMEX-###`**, globally sequential
(`max(GitHub, local files) + 1`), never restarted; dependency order is respected; tests ship with
every issue and the LLM provider is **`MOCK`** in tests (no paid calls); a **seam change** updates
`specification/ARCHITECTURE.md` and its contract test in the same commit; releases are `vA.B.C`
tags cut per phase, and a version is **never bumped without explicit confirmation**.

## Tracking and the dashboard

The hooks in `.claude/settings.json` emit events to `codegen/runs/<run-id>/events.jsonl` during any
tracked run; the skills emit their own richer events via `python3 -m tracker.emit`. The dashboard
reduces that log live:

```bash
python3 -m venv .venv
.venv/bin/pip install -r codegen/requirements.txt
cd codegen && ../.venv/bin/python -m uvicorn dashboard.server:app --port 8420
```

Open <http://127.0.0.1:8420/>. Port 8420, never 8000. `codegen/runs/` is gitignored — the logs are
per-machine evidence. Full detail, panels, and test instructions: [codegen/README.md](codegen/README.md).

## Resetting a run

`/reset-generated` deletes what a tracked run created — file list derived from the run's own event
log and git (`--diff-filter=A`), release tags removed, `specification/implementation/` cleared whole.
It never touches `codegen/`, `.claude/`, the specs, `.env*`, or GitHub issues, and it is dry-run by
default. Use it only for deliberate regeneration experiments — for Myrmex the generated app is the
product, so a reset is the exception, not the cycle.
