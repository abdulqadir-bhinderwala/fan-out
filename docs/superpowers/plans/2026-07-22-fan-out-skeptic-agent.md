# Mandatory Skeptic Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth swarm role — one persistent, mandatory `skeptic` agent with evidence-gated hard-block authority — to the `/fan-out` skill.

**Architecture:** This repo is a Claude Code skill, not an application. The deliverable is prose instructions the model follows at runtime. Two files carry the same contract at two levels of depth: `skills/fan-out/SKILL.md` is the compact operational loop, `skills/fan-out/reference/PLAYBOOK.md` is the expanded reference. Both must state the skeptic contract consistently — a divergence between them is the defect this plan must avoid.

**Tech Stack:** Markdown only. No code, no build, no test framework. Verification is read-back plus grep-based cross-file consistency checks.

## Global Constraints

Copied verbatim from `docs/superpowers/specs/2026-07-22-fan-out-skeptic-agent-design.md`:

- Agent name is exactly `skeptic` (lowercase, no `-lane` suffix).
- Spawned on **every** `/fan-out` invocation. No triage exception.
- Persistent for the run; reused via SendMessage; never spawned twice; killed at program end.
- **Not** inherited by sub-controllers — no sub-skeptics at any recursion depth.
- Consulted at exactly three gate types: plan gate, task gate, whole-branch gate.
- A `BLOCK` is valid only with: `file:line` + why wrong, a concrete failing input/repro, spec line X contradicted by code Y, or a missing artifact that should exist.
- Unevidenced concern auto-downgrades to a tracked **Minor** — logged, non-gating.
- Any open BLOCK gates (Critical **and** Important). Severity sets fix urgency only. Minors never gate.
- Fixes are re-checked by **the skeptic itself**, not the reviewer.
- Override is allowed but requires the exact ledger form: `OVERRIDE T4: <block> — reason: <why> — controller`
- Overrides are listed to the human in the final report.
- Existing writing style: em-dashes, **bold** lead-ins on bullets, terse imperative voice. Match it.

---

### Task 1: Add the skeptic to `SKILL.md`

**Files:**
- Modify: `skills/fan-out/SKILL.md` (five separate edits, listed per step)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the canonical wording of the role row, the evidence bar, the verdict contract, the override ledger line, and the safety invariant. Task 2 must reuse these exact phrasings — specifically the strings `skeptic`, `evidence bar`, `tracked Minor`, and `OVERRIDE T4: <block> — reason: <why> — controller`.

- [ ] **Step 1: Change the roles heading and add the Skeptic row**

In `skills/fan-out/SKILL.md`, replace the heading line:

```
## Three roles (always)
```

with:

```
## Four roles (always)
```

Then, in the table immediately below it, add this row after the `**Reviewer**` row (the last row, ending in `Write code; rubber-stamp |`):

```
| **Skeptic** | One persistent subagent named `skeptic`, spawned at program start, killed at program end | Attack the plan before dispatch, audit skill compliance, dispute every claim of done — blocking only on evidence | Write code; block without evidence; be spawned twice |
```

- [ ] **Step 2: Add the skeptic-vs-reviewer distinction line**

Directly below that table sits the line:

```
Your leverage is **curating context**: each agent gets a hand-built brief *file*, not session history.
```

Insert this paragraph **above** that line, separated by a blank line:

```
**Skeptic ≠ Reviewer.** The reviewer is fresh per task and reads one diff for correctness and security. The skeptic is **persistent and remembers** — it goes at *claims, process, and plan shape* across the whole program. That memory is why it can't be folded into the reviewer.
```

- [ ] **Step 3: Wire the skeptic into the loop**

In the `## The loop (run this)` numbered list, replace step 3:

```
3. **Branch.** Record the base commit. Seed the ledger (`.superpowers/sdd/progress.md`).
```

with:

```
3. **Branch.** Record the base commit. Seed the ledger (`.superpowers/sdd/progress.md`). **Spawn the `skeptic`** — every run, no exceptions, even a one-line task.
```

Replace step 5:

```
5. **Viewer:** detect best available multiplexer → set up panes; else headless (see below).
```

with:

```
5. **Plan gate:** send the wave decomposition to the `skeptic` before dispatching. It attacks non-disjoint files, faked parallelism on a dependency chain, missing requirements, unstated failure modes. Clear its blocks, then set up the **viewer:** detect best available multiplexer → set up panes; else headless (see below).
```

Replace step 7:

```
7. **Per task gate:** lane reports → **you verify the actual diff** → fresh reviewer (adversarial) → fix loop if Critical/Important → **bank in ledger + commit stands**.
```

with:

```
7. **Per task gate:** lane reports → **you verify the actual diff** → fresh reviewer (adversarial) → **`skeptic` disputes the done-claim and audits skill compliance** → fix loop if Critical/Important → **bank in ledger + commit stands**.
```

Replace step 10:

```
10. **Whole-branch review** (top model, once) → batch-fix findings → re-review.
```

with:

```
10. **Whole-branch review** (top model, once) + **`skeptic` final pass** (it carries every earlier objection) → batch-fix findings → re-review. Kill the `skeptic` after it clears.
```

- [ ] **Step 4: Add the lifecycle bullet**

In `## Agent lifecycle — spawn, reuse, kill`, the last bullet reads:

```
- **One persistent reviewer** is the exception worth reusing across tasks (accumulates review context) — still kill it at program end.
```

Add this bullet directly after it:

```
- **The `skeptic` is always persistent, never duplicated, never inherited.** One per run, spawned at branch time regardless of task size, messaged by name for every gate, killed at program end. **Sub-controllers do not spawn sub-skeptics** — a recursing lane's work is gated when its *integrated* diff reaches the top-level skeptic, as one unit.
```

- [ ] **Step 5: Rewrite the review-gates section for three checks**

In `## Review gates — why swarms stay correct`, replace this line:

```
Parallel speed is worthless if it ships bugs. Every task passes **two** checks; neither is "tests are green":
```

with:

```
Parallel speed is worthless if it ships bugs. Every task passes **three** checks; none of them is "tests are green":
```

Then, after the numbered item 2 (`**Fresh reviewer** — ...`), add item 3:

```
3. **Skeptic** — the persistent doubter disputes the *claim*, not just the code: is "done" supported by the diff and the test output, or is it a confident report? Was the process actually followed (TDD red phase in `git log`, not just green tests)? It carries memory across tasks — a lane that overstated once gets more scrutiny later.
```

Directly below the numbered list, before the `- **Per-task review** gates each task.` bullet, insert:

```
**The skeptic blocks, but only on evidence.** A `BLOCK` is valid only when it cites one of: `file:line` + why it's wrong; a concrete failing input or repro; a spec line contradicted by code; or a missing artifact that should exist. Anything weaker auto-downgrades to a **tracked Minor** — logged in the ledger, non-gating. Say this in its dispatch so it self-filters instead of you arguing findings down. Without this bar, a skeptic with blocking power deadlocks the swarm on vibes.

It reports to a file:

`VERDICT: PASS | BLOCK` / `BLOCKS: [severity] evidence → the claim it refutes` / `MINORS: unevidenced concerns (tracked, non-gating)`

**Any open BLOCK gates** — Critical and Important both stop the gate; severity only sets fix urgency. Two exits: **fix** → focused dispatch → **the skeptic re-checks its own block** (not the reviewer — persistence is the point), or **override** → allowed, but it costs a ledger line, never a silent bypass:

`OVERRIDE T4: <block> — reason: <why> — controller`

List every override to the human in the final report.
```

- [ ] **Step 6: Add the safety invariant**

In `## Safety invariants (never traded for speed)`, add this bullet directly after the bullet beginning `- Never fake a human gate`:

```
- **The `skeptic` is not optional and cannot be dismissed silently.** Every run spawns it; every open block is fixed or recorded as a controller override in the ledger. A gate passed without the skeptic's verdict is not a passed gate.
```

- [ ] **Step 7: Verify the edits landed**

Run:

```bash
grep -n "skeptic\|Skeptic" skills/fan-out/SKILL.md
```

Expected: at least 12 matching lines, spanning the roles table, the distinction paragraph, loop steps 3/5/7/10, the lifecycle bullet, the review-gates section, and the safety invariant.

Run:

```bash
grep -c "Three roles" skills/fan-out/SKILL.md
```

Expected: `0` — the heading was changed to "Four roles".

- [ ] **Step 8: Commit**

```bash
git add skills/fan-out/SKILL.md
git commit -m "fan-out: mandatory skeptic agent in the operational loop"
```

---

### Task 2: Add the skeptic to `PLAYBOOK.md` and verify cross-file consistency

**Files:**
- Modify: `skills/fan-out/reference/PLAYBOOK.md` (five separate edits, listed per step)
- Read for consistency: `skills/fan-out/SKILL.md` (already edited in Task 1 — do not modify it here)

**Interfaces:**
- Consumes from Task 1: the exact strings `skeptic`, `evidence bar`, `tracked Minor`, the verdict contract keys `VERDICT` / `BLOCKS` / `MINORS`, and the override line `OVERRIDE T4: <block> — reason: <why> — controller`. Read `skills/fan-out/SKILL.md` first and reuse those phrasings verbatim; the two files diverging is the defect this task exists to prevent.
- Produces: nothing downstream (final task).

- [ ] **Step 1: Add the Skeptic row to the §1 role table**

In `skills/fan-out/reference/PLAYBOOK.md` §1, replace:

```
Three roles, always:
```

with:

```
Four roles, always:
```

Add this row to the table below it, after the `**Reviewer**` row:

```
| **Skeptic** | One persistent subagent named `skeptic`, spawned at program start, killed at program end | Attack the plan before dispatch, audit skill compliance, dispute every claim of done — blocking only on evidence | Write code; block without evidence; be spawned twice |
```

- [ ] **Step 2: Add the distinction paragraph to §1**

§1 ends with:

```
The controller's leverage is **curating context**: each lane/reviewer gets a hand-built brief (a file), not the session history. This keeps every agent focused and keeps the controller's own context clean.
```

Insert this paragraph **above** that line, separated by a blank line:

```
**Skeptic is not a second reviewer.** The reviewer is fresh per task and reads one diff for correctness and security — it has no memory and no view of the plan. The skeptic is persistent, and goes at **claims, process, and plan shape** across the whole program: it attacks the decomposition before any lane spawns, it asks whether the process skills were actually followed rather than claimed, and a lane that overstated "done" in task 2 gets sharper scrutiny in task 7. That accumulated memory is precisely what a fresh-per-task reviewer structurally cannot have, and it is why this is a distinct role rather than a longer reviewer prompt.
```

- [ ] **Step 3: Add the lifecycle rules to §4**

In §4 (`Agent lifecycle — spawn, reuse, kill`), find:

```
**One persistent reviewer** is the exception worth keeping: reuse it across tasks by messaging it, so it accumulates review context — but still kill it at program end.
```

Insert this paragraph directly after it:

```
**The `skeptic` is mandatory, persistent, singular, and non-recursive.** Spawn it at branch time on **every** run — a one-line typo fix gets a skeptic too; there is no triage exception, because a rule with a discretionary crack gets widened under time pressure. Message it by name at each gate; never spawn a second one (a duplicate `skeptic` is the same bug as `api-lane-2`). Kill it at program end after its final pass clears. **Sub-controllers do not spawn sub-skeptics at any depth** — a recursing lane's sub-work is gated when the lane's *integrated* diff reaches the top-level skeptic, consistent with the rule that you gate a lane's rolled-up result rather than its leaf agents.
```

- [ ] **Step 4: Add §5.1, the skeptic gate**

In §5 (`The review gates — why swarms stay correct`), replace:

```
Parallel speed is worthless if it ships bugs. Every task passes **two** checks, and neither is "tests are green":
```

with:

```
Parallel speed is worthless if it ships bugs. Every task passes **three** checks, and none of them is "tests are green":
```

Add item 3 to that numbered list, after item 2 (`**Fresh reviewer** — ...`):

```
3. **Skeptic** — the persistent doubter attacks the *claim*, not just the code. Is "done" supported by the diff and actual test output, or is it a confident report? Was the process followed (a red phase in `git log`, not merely green tests at the end)? It carries every earlier objection forward.
```

Then, immediately before the existing `Model selection for reviewers:` line at the end of §5, insert this subsection (the outer fence below is four backticks because the content contains a fenced block — insert only the inner content):

````
### 5.1 The skeptic gate

The skeptic is consulted at exactly three points:

1. **Plan gate** — before Wave 1 dispatch, when findings are cheapest to act on. It attacks the decomposition: files that are not actually disjoint, parallelism faked on a dependency chain, missing requirements, unstated failure modes.
2. **Task gate** — after you verify the diff and the reviewer returns its verdict. It disputes the done-claim and audits skill compliance.
3. **Whole-branch gate** — a final pass alongside the top-model review, carrying its accumulated memory of every earlier objection.

**Evidence bar.** A `BLOCK` is valid only when it cites one of:

- `file:line` plus why it is wrong;
- a concrete failing input or repro;
- a spec line X contradicted by code Y;
- a missing artifact that should exist (no red-phase commit, no test output).

Anything below that bar auto-downgrades to a **tracked Minor**: recorded in the ledger, non-gating. State this rule in the skeptic's dispatch so it self-filters, rather than you having to argue findings down. This bar is what makes hard-block authority safe — a skeptical persona plus blocking power, with no evidence requirement, deadlocks the swarm on vibes.

**Verdict contract.** The skeptic writes to a report file:

```
VERDICT: PASS | BLOCK
BLOCKS:  [severity] evidence → the claim it refutes
MINORS:  unevidenced concerns (tracked, non-gating)
```

Severity uses the existing scale. **Any open BLOCK gates** — Critical and Important both stop the gate; severity only sets fix urgency. Minors never gate. You cannot bank a task or dispatch a wave while a block is open. Two exits:

- **Fix** → focused fix dispatch → **the skeptic re-checks its own block**, not the reviewer. Persistence is the point; a fresh checker loses the context that produced the block.
- **Override** → permitted, but it costs a ledger line. No silent bypass:

  `OVERRIDE T4: <block> — reason: <why> — controller`

Every override is listed to the human in the final report.
````

- [ ] **Step 5: Add the invariant and the checklist steps**

In §9 (`Safety & quality invariants`), add this bullet directly after the bullet beginning `- **Never fake a human gate.**`:

```
- **The skeptic is not optional and cannot be dismissed silently.** Every run spawns it; every open block is fixed or recorded as a controller override in the ledger. A gate passed without the skeptic's verdict is not a passed gate.
```

In §10 (the end-to-end checklist), replace step 3:

```
3. **Branch.** Record the base commit. Seed the ledger.
```

with:

```
3. **Branch.** Record the base commit. Seed the ledger. **Spawn the `skeptic`** (every run, no exceptions).
```

Replace step 5's opening so the plan gate precedes the viewer — change:

```
5. **Viewer:** detect the best available multiplexer
```

to:

```
5. **Plan gate:** the `skeptic` attacks the decomposition before dispatch; clear its blocks. Then **viewer:** detect the best available multiplexer
```

Replace step 7:

```
7. **Per task:** lane reports → controller verifies the diff → fresh reviewer → fix loop if needed → **bank in ledger + commit stands**.
```

with:

```
7. **Per task:** lane reports → controller verifies the diff → fresh reviewer → **`skeptic` disputes the done-claim** → fix loop if needed → **bank in ledger + commit stands**.
```

Replace step 10:

```
10. **Whole-branch review** (top model) → batch-fix findings → re-review.
```

with:

```
10. **Whole-branch review** (top model) + **`skeptic` final pass** → batch-fix findings → re-review → kill the `skeptic`.
```

- [ ] **Step 6: Verify cross-file consistency**

Run:

```bash
grep -c "skeptic\|Skeptic" skills/fan-out/SKILL.md skills/fan-out/reference/PLAYBOOK.md
```

Expected: both files non-zero; PLAYBOOK.md's count is the higher of the two (it is the expanded reference).

Run:

```bash
grep -n "OVERRIDE T4" skills/fan-out/SKILL.md skills/fan-out/reference/PLAYBOOK.md
```

Expected: exactly one match in each file, and the two lines are byte-identical apart from indentation.

Run:

```bash
grep -n "Three roles\|three roles" skills/fan-out/SKILL.md skills/fan-out/reference/PLAYBOOK.md
```

Expected: no matches — both headings now say four.

Then read both files and confirm by eye:

- The evidence-bar criteria list is the same four items in both files.
- Both say sub-controllers do **not** spawn sub-skeptics.
- Both say the skeptic re-checks its own block, not the reviewer.
- Neither file describes a triage exception to the mandatory spawn.

Fix any divergence in `PLAYBOOK.md` (treat `SKILL.md` from Task 1 as canonical for shared phrasings).

- [ ] **Step 7: Commit**

```bash
git add skills/fan-out/reference/PLAYBOOK.md
git commit -m "fan-out: expand skeptic agent contract in the playbook"
```
