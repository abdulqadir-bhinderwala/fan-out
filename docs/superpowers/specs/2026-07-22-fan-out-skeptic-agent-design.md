# Design: Mandatory Skeptic Agent for `/fan-out`

Date: 2026-07-22
Status: Approved

## Problem

`/fan-out` already gates work through two checks: controller diff verification and a fresh per-task adversarial reviewer. Both are **fresh-per-task and code-scoped**. Neither of them:

- attacks the *plan* before lanes spawn, when findings are cheapest to act on;
- audits whether the process skills (TDD, systematic-debugging, brainstorming) were actually followed rather than claimed;
- accumulates memory across tasks, so a lane that overstated "done" in task 2 gets no extra scrutiny in task 7.

The controller is also its own judge on whether to act on concerns, and nothing records a dismissed concern.

## Solution

Add a fourth role to the swarm: a single **persistent skeptic agent**, spawned on every run, with hard-block authority gated behind an evidence bar.

### 1. Fourth role

Added to the three-roles table in `SKILL.md` and `PLAYBOOK.md` §1:

| Role | Who | Does | Never |
|---|---|---|---|
| **Skeptic** | One persistent subagent named `skeptic`, spawned at program start, killed at program end | Attack the plan before dispatch; audit skill compliance; dispute every claim of done. Blocks on evidence. | Write code; block without evidence; be spawned twice |

**Distinction from Reviewer** (must be stated explicitly in the docs, or the two roles collapse):
the reviewer is *fresh per task and reads one diff for correctness and security*. The skeptic is *persistent and remembers*, and goes at **claims, process, and plan shape** across the whole program. The memory is the reason this cannot be folded into the reviewer role.

### 2. Lifecycle and mandatory spawn

- Spawned on **every** `/fan-out` invocation. No triage exception — a one-line typo fix still gets a skeptic. The rule has no discretionary crack.
- **Persistent**: reused across tasks via SendMessage. Never spawned twice; a second `skeptic` is the same duplicate-lane bug the existing lifecycle rules forbid.
- Killed at program end. Existing zombie-audit rules apply unchanged.
- **Not inherited by sub-controllers.** A recursing lane spawns no sub-skeptic. The top-level skeptic gates that lane's *integrated* diff as a single unit, consistent with the existing rule that the controller gates a lane's rolled-up result rather than its leaf agents.

Consulted at three gate types:

1. **Plan gate** — before Wave 1 dispatch. Attacks the decomposition: files that are not actually disjoint, faked parallelism on a dependency chain, missing requirements, unstated failure modes.
2. **Task gate** — after the controller verifies the diff and the reviewer returns its verdict. Disputes the done-claim and audits skill compliance (was TDD actually followed — is there a red phase in `git log`?).
3. **Whole-branch gate** — final pass, carrying its accumulated memory of every earlier objection.

### 3. Evidence bar

A `BLOCK` is valid only when it cites one of:

- `file:line` plus why it is wrong;
- a concrete failing input or repro;
- a spec line X contradicted by code Y;
- a missing artifact that should exist (no red-phase commit, no test output).

Anything below that bar auto-downgrades to a tracked **Minor**: recorded in the ledger, non-gating. The skeptic's dispatch states this rule explicitly so it self-filters, rather than the controller having to argue findings down.

This is what makes hard-block authority safe: without it, a skeptical persona plus blocking power deadlocks the swarm on vibes.

### 4. Verdict contract and override

The skeptic writes to a report file:

```
VERDICT: PASS | BLOCK
BLOCKS:  [severity] evidence → the claim it refutes
MINORS:  unevidenced concerns (tracked, non-gating)
```

Severity uses the existing scale (Critical / Important / Minor). **Any open BLOCK gates** — Critical and Important both stop the gate; severity only sets fix urgency. Minors never gate. The controller cannot bank a task or dispatch a wave while a block is open. Two exits:

- **Fix** → focused fix dispatch → **the skeptic re-checks its own block** (not the reviewer). Persistence is the point; a fresh checker loses the context that produced the block.
- **Override** → permitted, but requires a ledger line. No silent bypass:
  `OVERRIDE T4: <block> — reason: <why> — controller`

All overrides are listed to the human in the final report.

### 5. Safety invariant

Added to the invariant lists in both files:

> **The skeptic is not optional and cannot be dismissed silently.** Every run spawns it; every open block is fixed or recorded as a controller override in the ledger. A gate passed without the skeptic's verdict is not a passed gate.

### 6. Files changed

- `skills/fan-out/SKILL.md` — role table row; spawn rule in the agent-lifecycle section; review-gate step updated to three checks; compact verdict contract; invariant line.
- `skills/fan-out/reference/PLAYBOOK.md` — same content expanded: §1 role table, a new skeptic subsection under §5, §9 invariant, §10 checklist steps.

No new files. The skeptic's persona and prompt live inline in the dispatch text, matching how lanes and reviewers are already specified in this skill.

## Rejected alternatives

- **Advisory-only skeptic** — a rushed controller ignores it precisely when it matters most, and nothing is recorded.
- **Risk-tiered blocking** (block on auth/money/data only) — reintroduces controller discretion about what counts as a risk surface.
- **Block budget instead of an evidence bar** — caps noise but does not raise quality; an unevidenced block still consumes a gate.
- **Sub-skeptics at every recursion level** — agent count grows with depth for work already gated at rollup.
- **Folding the skeptic into the per-task reviewer for small tasks** — creates the triage exception the mandatory rule exists to prevent.
