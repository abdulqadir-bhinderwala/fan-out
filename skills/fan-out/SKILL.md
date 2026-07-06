---
name: fan-out
description: Orchestrate a swarm of subagents to build in parallel. A controller decomposes work into file-disjoint waves, spawns named specialist lane agents, gates every result through adversarial reviewers, and keeps a durable ledger — so one task or a whole BRD ships fast without losing rigor. Use when the user types /fan-out, or asks to fan out / parallelize / swarm / run multiple agents across a task, feature, or spec. Cross-platform (macOS/Linux/Windows), works with or without tmux.
---

# /fan-out — Agent-Swarm Orchestration

Turn this session into a small software company: a **controller** (you) that decomposes work, spawns **specialist lane agents** to build in parallel, gates every result through **adversarial reviewers**, and keeps a **durable paper trail**. Default behavior is intelligent + efficient; the optional second argument overrides the swarm setup.

**Full reference:** `reference/PLAYBOOK.md` (in this skill dir) — read it for depth on any step. This SKILL.md is the operational loop.

## Invocation

```
/fan-out <task | spec/BRD path | description> [optional swarm setup]
```

Parse the argument into: (1) the **work** and (2) any **setup overrides** in natural language — e.g. `... with 3 backend lanes and a security reviewer`, `... no tmux`, `... cheapest models`, `... don't touch payments`, `... run to completion, don't check in`. With no overrides, **you decide** lane count, model tiers, review depth, and viewer from the task itself.

## Three roles (always)

| Role | Who | Does | Never |
|---|---|---|---|
| **Controller** | You (main session) | Decompose, spawn/steer lanes, gate reviews, integrate, keep ledger | Write feature code (stay free to coordinate) |
| **Lane** | Spawned subagent, named by domain (`api-lane`, `ui-lane`, `spa-lane`, `infra-lane`, `domain-lane`) | Build one task in **its own files**, TDD, commit, self-review, report. If the task is large + disjoint, **sub-fan-out** its own worker sub-agents (see *Recursive fan-out*) | Touch another lane's files; approve itself |
| **Reviewer** | Spawned subagent, fresh-per-task or persistent-reused | Read diff adversarially, verify spec + security, return verdict | Write code; rubber-stamp |

Your leverage is **curating context**: each agent gets a hand-built brief *file*, not session history.

## The loop (run this)

1. **Triage** the input: one small task vs feature vs BRD → pick lifecycle depth.
   - **Small task** → single lane + reviewer (or do it yourself). Skip to step 5.
   - **Feature / BRD** → run the process chain first (step 2).
2. **Process chain (feature/BRD only):** `superpowers:brainstorming` → spec (design gate: user/PO approves) → `superpowers:writing-plans` → plan (write gate: self-review clean). Decompose a too-big BRD into sub-projects first (independent pieces + build order), each through its own chain. Then `superpowers:subagent-driven-development` drives execution — /fan-out orchestrates these skills at swarm scale, it doesn't replace them.
3. **Branch.** Record the base commit. Seed the ledger (`.superpowers/sdd/progress.md`).
4. **Decompose into waves** (see below).
5. **Viewer:** detect best available multiplexer → set up panes; else headless (see below).
6. **Dispatch a wave** of lanes in parallel — named, brief-file-driven, model-tiered. **Grant capable lanes permission to sub-fan-out** when their task is large and internally disjoint (see *Recursive fan-out*).
7. **Per task gate:** lane reports → **you verify the actual diff** → fresh reviewer (adversarial) → fix loop if Critical/Important → **bank in ledger + commit stands**.
8. **Sequence** cross-deps at gates; release parallel tasks where files are disjoint.
9. **Kill** each lane at completion; audit for zombies between phases.
10. **Whole-branch review** (top model, once) → batch-fix findings → re-review.
11. **Finish the branch** (`superpowers:finishing-a-development-branch`, merge/PR per human) → update roadmap %.
12. **Report** to the human plainly: what shipped, what's verified, what's tracked.

## Decompose into parallel waves

1. **List the files/units** the work touches — scout inline (grep, read structure) before deciding shape.
2. **Build the dependency graph** — what must exist before what.
3. **Group into waves** — a wave = tasks that run at the same time because they touch **disjoint files** and their deps are met.
4. **Assign lanes by file ownership** — each lane owns a directory/package; two lanes never edit the same file. Shared lockfile → one lane is **first-mover** on installs, others re-run if they race.
5. **Sequence cross-deps at gates**, not inside a wave.

**Parallelism is only safe on disjoint files.** Two tasks editing the same file = one lane's sequential work. **Fan out where the graph is wide; chain where it's deep. Don't fake parallelism on a dependency chain.** (Worktrees `isolation:"worktree"` are the escape hatch for true parallel edits — cost setup + merge, avoid unless necessary.)

## Agent lifecycle — spawn, reuse, kill

- **Spawn** a lane with a **name = its role**. Give it: (1) one line on where the task fits, (2) the brief-file path (its requirements — exact code/strings/signatures live in the file, not the prompt), (3) interfaces/decisions from earlier tasks it can't know, (4) your resolution of any ambiguity, (5) the report-file path + report contract.
- **Reuse** an idle existing lane by **messaging it by name** (SendMessage) with its next brief — do NOT spawn a duplicate. `api-lane-2` while `api-lane` lives = two agents in one tree = file races.
- **Kill** every agent when its work is done — **actually stop it** (TaskStop), don't just message "stand down." A stand-down message leaves the process alive as a zombie that auto-picks-up tasks and collides. Kill at each lane's completion and at program end; periodically audit for zombies.
- **One persistent reviewer** is the exception worth reusing across tasks (accumulates review context) — still kill it at program end.

## Recursive fan-out — lanes may spawn their own sub-lanes

When a lane's task is itself **large and internally decomposable** (many disjoint files / independent sub-parts), let the lane act as a **sub-controller**: it splits its task into sub-briefs, spawns its own worker sub-agents in parallel (the Agent tool), gates + integrates them, then reports up. **Recurse wherever the sub-graph is wide** — it's the main lever for going faster on big tasks. A lane doesn't recurse unless you grant it.

Put the grant + guardrails in the lane's brief/prompt when you enable it:

- **Enable explicitly.** In the dispatch, say: *"You MAY spawn your own sub-agents if your task decomposes into disjoint parallel pieces; you then act as their controller — verify each sub-diff, kill them when done, report the integrated result."* Prefer this **wherever it buys real parallelism**.
- **Same disjoint-files rule, one level down.** The lane partitions *its own* file boundary among sub-lanes; two sub-lanes never touch the same file. The lane owns integration + any shared file (its package's index/lockfile).
- **A sub-controller runs the same gates:** it verifies each sub-agent's actual diff, reviews risky sub-diffs adversarially, and does **not** pass unverified sub-work upward. Skipping its own gates is as unsafe as a controller skipping them.
- **Depth cap: 2 levels by default** (controller → lane → sub-lane). Go to 3 only when a sub-task is itself clearly wide. **Never recurse on a dependency chain** (deep, not wide) — that adds coordination cost, not speed.
- **Shared budget.** The concurrent-agent cap is shared across the whole tree; every live agent is cost + collision risk. Prefer a few well-scoped sub-lanes over many tiny ones. Kill sub-lanes at their completion (zombie audits apply at every level).
- **Report contract unchanged upward:** the lane returns one report (files, test output, sub-review verdicts) as if it did the work itself — you gate the lane's integrated result, not each leaf agent.

Rule of thumb: **recurse where the sub-graph is wide, build inline where it's small.** Lane with 5 disjoint files → sub-fan-out. Lane with one file → just build it.

## Review gates — why swarms stay correct

Parallel speed is worthless if it ships bugs. Every task passes **two** checks; neither is "tests are green":

1. **Controller verification** — you read the actual diff for the load-bearing property (the guard clause, the money math, the auth check). A green suite + confident report is an unverified claim until the diff confirms it.
2. **Fresh reviewer** — a subagent reads the diff **adversarially**: matches spec (nothing missing/extra), secure/correct. For auth/money/data seams, prompt it to **attack the design** ("can a X do Y they shouldn't?") and point it at the structural analog of any bug already found.

- **Per-task review** gates each task. Critical/Important → focused fix dispatch → **re-review the fix** (don't trust it either).
- **Whole-branch review** at program end, **top model**, reads all commits as a whole — catches cross-task gaps a per-task review structurally can't.
- **Verify every fix by reading it.** Scale reviewer model to the diff's risk.

> This layered review is the single highest-value habit — it repeatedly catches authorization holes that tests + author + your own first read all passed, because tests prove *behavior* but only an adversarial reader proves *who-can-do-what*.

## Durable state — surviving compaction

Conversation memory does not survive compaction; a controller that loses its place can re-dispatch completed work (most expensive failure). **State lives in files:**

- **Progress ledger** — one line per task as its review clears: `Task N: complete (commits base..head, review clean)`, plus tracked Minors + cross-task notes. Recovery map after compaction: trust ledger + `git log` over memory.
- **Brief + report files** — referenced by path; bulk artifacts move as files, never pasted into prompts (pasted text re-enters context every later turn).
- **Git commits** — ground truth, one per green task. **Specs/plans/roadmap** — every decision committed.
- **Resume protocol:** on start/after compaction, read ledger + `git log`; tasks marked complete are done — resume at first unmarked.

## Viewer — cross-platform, multiplexer-optional

**Orchestration is 100% OS-agnostic** (agents + files + git + ledger). Same work, same rigor on **macOS/Linux/Windows**, with or without a multiplexer — the viewer is only the human's live window. Detect best available:

1. **tmux** — macOS/Linux native, Windows via WSL. `command -v tmux` / `$TMUX`.
2. **zellij** — modern multiplexer, **native on Windows** too. `command -v zellij`.
3. **Windows Terminal** split panes — `wt split-pane` (or WezTerm/ConEmu/PowerShell splitter).
4. **Headless (always works)** — no multiplexer: the **ledger file is the live status**. Human tails it (`tail -f` POSIX / `Get-Content -Wait` PowerShell); you write a status line to the ledger at every gate.

Pane recipe (any multiplexer): one window, three regions, controller widest (~70%), a status pane looping `git log --oneline -10; tail -n5 ledger; sleep 4`, plus a free shell. **Never block or reduce the work because a multiplexer is missing** — viewer is cosmetics, ledger is the record.

## Efficiency defaults

- **Context curation over dumping** — brief file + interfaces, not the transcript. Keep your own context lean.
- **Model tiering** — transcription (plan has exact code) → cheapest; prose-spec implementation + integration → mid; design + final whole-branch review → top. **Always set the model explicitly** (omitted = inherits most expensive).
- **Turn-count beats token-price** — cheapest models take 2–3× the turns on multi-step work; mid-tier is the floor for reasoning tasks.
- **Fan out only where the graph is wide.** **Pipeline, don't barrier** — let items flow when a later stage needs one item's prior stage, not the whole wave. For large deterministic fan-outs, a Workflow script beats manual dispatch.
- **Release the next task in parallel with a review** when files differ. **Stop idle agents** — every alive agent is latent cost + collision risk.

## Safety invariants (never traded for speed)

- Never trust "done" — verify the diff. Never skip the review gate on an auth/money/data-integrity surface.
- Never run two agents in the same file/working-tree concurrently — **at any level.** Recursion follows the same rules everywhere: disjoint files, verify-the-diff, kill-when-done, depth cap.
- Never fake a human gate — sign-offs (spec approval, UAT, launch) are recorded when the human relays them, never self-approved.
- Never lose the paper trail (ledger + git + committed specs/plans).
- Adversarial review for authorization. Fail closed (guards deny on missing context; prefer 4xx over silent success).
- Destructive ops get a backup first (branch/stash) and are surfaced, not done silently.
