---
name: upload-issues
description: Upload issues from a phase issues file to GitHub one by one with proper labels and dependencies.
---

# Skill: Upload Version Issues to GitHub

Upload issues from a phase issues file to GitHub one by one, with proper labels
(prefixed by version) and dependencies.

## Usage

```
/upload-issues <phase-issues-file>
```

Example: `/upload-issues @specification/implementation/v0.2-issues.md`

A phase issues file is the fine-grained breakdown of a ROADMAP phase (`vA.B`): each
phase in [specification/ROADMAP.md](../../../specification/ROADMAP.md) is split into one or more
`MYRMEX-###` issues by `/generate-issues`. If the file does not exist yet, run
`/generate-issues <phase>` first, then this skill.

## Instructions

### Step 1: Read the phase issues file

Read the provided file (e.g., `specification/implementation/v{A.B}-issues.md`).

Determine from the file:
- **Version number** (A): the roadmap version the phase sits under (e.g. `v0.2` → `0`).
- **Phase** (A.B): from the filename or heading (e.g., `v0.2-issues.md` → `v0.2`).
- **Label prefix**: `v{A.B}::` (e.g., `v0.2::`).

Parse the **Issues Summary Table** to extract for each issue:
- `ID` (e.g., MYRMEX-001)
- `Title`
- `Size` (S, M, L)
- `Area` (the component: `sim`, `view`, `ui`, `llm`, `data`, `tools`, `tests`)
- `Phase` (the ROADMAP phase it implements, e.g. `v0.2`)
- `Dependencies` (list of MYRMEX-### IDs)

Then parse each **detailed issue section** (heading with MYRMEX-###) to extract:
`Description`, `What needs to be done`, `Dependencies`, `Expected result`,
`Acceptance criteria` (should align with the phase DoD in ROADMAP.md).

### Step 2: Confirm with user

Show the user a summary of what will be created: number of issues, label prefix (e.g.,
`v0.2::`), the full list of labels, and ask for confirmation before proceeding.

### Step 3: Create labels (if they don't exist)

All labels MUST be prefixed with `v{A.B}::`. Label format: `v{A.B}::{category}:{value}`.

Version titles: **v0 — Prototype "First Night"**; **v1 — The full nest**; **v2 — Births**;
**v3 — Replay**; **v4 — Server and clients**; **v5 — Nests at war**;
**v6 — Evolution and the genome**.

```bash
# Phase label
gh label create "v0.2::phase" --color "0E8A16" --description "Phase v0.2" 2>/dev/null || true

# Size labels
gh label create "v0.2::size:S" --color "28A745" --description "Small (1-2 days)" 2>/dev/null || true
gh label create "v0.2::size:M" --color "FFC107" --description "Medium (3-5 days)" 2>/dev/null || true
gh label create "v0.2::size:L" --color "DC3545" --description "Large (5-8 days)" 2>/dev/null || true

# Area labels (one per component touched in this phase)
gh label create "v0.2::area:sim"  --color "6F42C1" 2>/dev/null || true
gh label create "v0.2::area:view" --color "1D76DB" 2>/dev/null || true
gh label create "v0.2::area:llm"  --color "0E8A16" 2>/dev/null || true
# ... ui / data / tools / tests as needed
```

### Step 4: Create issues ONE BY ONE

**IMPORTANT:** Issues must be created one at a time, sequentially. After creating each
issue, show the user the result (issue number, URL) and proceed to the next immediately
(do not wait for confirmation between issues).

For each issue (in order from the summary table):

1. Build the issue body in markdown:

```markdown
## Description
{description}

## What needs to be done
{full content}

## Dependencies
{dependency list, with references to already-created issue numbers}

## Expected result
{expected result}

## Acceptance criteria
{checklist}

---
**ID:** {MYRMEX-###}
**Size:** {S/M/L}
**Version:** v{A}
**Area:** {sim/view/ui/llm/data/tools/tests}
**Phase:** {vA.B from roadmap}
```

2. Create the issue with a single `gh issue create` command (one issue per command, never batch):

```bash
gh issue create \
  --title "MYRMEX-###: {title}" \
  --label "v0.2::phase,v0.2::size:{S/M/L},v0.2::area:{area}" \
  --body "$(cat <<'BODY'
{issue body}
BODY
)"
```

3. Record the mapping: MYRMEX-### -> GitHub issue #number
4. Report to user: `Created MYRMEX-### -> #{number}: {title}`
5. If the issue depends on already-created issues, add a comment:
   ```bash
   gh issue comment {issue-number} --body "Blocked by #{dep-issue-number} (MYRMEX-###)"
   ```
6. Move to the next issue.

### Step 5: Generate report

After all issues are created, generate `specification/implementation/v{A.B}-github-report.md`:

```markdown
# Phase v{A.B} -- GitHub Issues Report

**Uploaded:** {date}
**Repository:** {github repo URL}
**Total issues:** {count}

## Issue Mapping

| MYRMEX ID | GitHub # | Title | Phase | Labels | URL |
|----------|----------|-------|-------|--------|-----|
| MYRMEX-001 | #5 | ... | v0.2 | v0.2::phase, v0.2::size:S, v0.2::area:sim | {url} |

## Labels Created

- v{A.B}::phase
- v{A.B}::size:S, v{A.B}::size:M, v{A.B}::size:L
- v{A.B}::area:{list}
```

### Step 5.5: Emit tracking events

After each `gh issue create`, emit `issue.uploaded` with the MYRMEX id, `gh_number` and `url`
(`--emitter skill:upload-issues --scope phase=..,version=..,step=upload-issues,issue=MYRMEX-###`).
This is what makes GitHub issues created/closed/open countable at all.

### Step 6: Report to user

Show the user: total issues created, link to the GitHub issues page, path to the
generated report file.

## Error Handling

- If `gh` is not authenticated, tell the user to run `gh auth login`
- If the repo has no GitHub remote yet, tell the user to create one (`gh repo create`) before uploading
- If an issue already exists with the same title, skip it and note in the report
- If label creation fails, continue (labels may already exist)
- On any failure, report what was created so far and what remains
