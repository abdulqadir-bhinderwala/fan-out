# `/fan-out` — Agent-Swarm Orchestration Playbook

> Turn one Claude session into a small software company: a **controller** that decomposes work, spawns **specialist lane agents** to build in parallel, gates every result through **adversarial reviewers**, and keeps a **durable paper trail** — so one task or an entire BRD gets built fast, in parallel, without losing rigor.
>
> This file is both the **how-to** and the **spec for a `/fan-out` command**. Default behavior is "very intelligent and efficient"; the optional second argument lets you override the swarm setup.

---

## 0. Invocation

```
/fan-out <task or BRD/spec path or description> [optional swarm setup]
```

- **`/fan-out add rate-limiting to the login endpoint`** — one small task. Controller does it directly or with 1 lane + 1 reviewer.
- **`/fan-out build the reporting module per docs/specs/reporting.md`** — a feature. Controller plans it, fans out lanes by file-boundary, reviews each.
- **`/fan-out ship the whole BRD at docs/BRD.docx`** — a program. Controller decomposes into sub-projects → each gets brainstorm → spec → plan → parallel build → review → finish.
- **Optional setup** (natural language): `... with 3 backend lanes and a security reviewer`, `... no tmux`, `... cheapest models`, `... don't touch the payments module`, `... run to completion, don't check in`.

**Default intelligence:** the controller decides lane count, model tiers, review depth, and tmux vs no-tmux from the task itself. You only pass setup when you want to override.

---

## 1. The core idea

Most AI coding is one agent doing one thing at a time. A swarm wins when work is **decomposable** and **file-disjoint**: independent pieces built in parallel by focused agents, each with exactly the context it needs, each verified before it's trusted.

Four roles, always:

| Role | Who | Does | Never |
|---|---|---|---|
| **Controller** (team-lead) | The main session (you) | Decompose, spawn/steer lanes, gate reviews, integrate, keep the ledger | Write feature code itself (it stays free to coordinate) |
| **Lane** (implementer) | A spawned subagent, named by domain (`api-lane`, `ui-lane`, `spa-lane`, `infra-lane`, `domain-lane`) | Build one task at a time in **its own files**, TDD, commit, self-review, report | Touch another lane's files; approve its own work |
| **Reviewer** | A spawned subagent, fresh per task or persistent-reused | Read the diff adversarially, verify spec + security, return a verdict | Write code; rubber-stamp |
| **Skeptic** | One persistent subagent named `skeptic`, spawned at branch time before any dispatch, killed at program end | Attack the plan before dispatch, audit skill compliance, dispute every claim of done — blocking only on evidence | Write code; block without evidence; be spawned twice |

**Skeptic is not a second reviewer.** The reviewer is fresh per task and reads one diff for correctness and security — it has no memory and no view of the plan. The skeptic is persistent, and goes at **claims, process, and plan shape** across the whole program: it attacks the decomposition before any lane spawns, it asks whether the process skills were actually followed rather than claimed, and a lane that overstated "done" in task 2 gets sharper scrutiny in task 7. That accumulated memory is precisely what a fresh-per-task reviewer structurally cannot have, and it is why this is a distinct role rather than a longer reviewer prompt.

The controller's leverage is **curating context**: each lane/reviewer gets a hand-built brief (a file), not the session history. This keeps every agent focused and keeps the controller's own context clean.

---

## 2. The lifecycle (scales from 1 task to a BRD)

```
                 ┌─────────────── one small task ───────────────┐
INPUT ─► triage ─┤                                              ├─► branch + spawn skeptic (every run, no exceptions)
                 └─ feature / BRD ─► brainstorm ─► spec ─► plan ─┘                     │
                                       │            │        │                         │
                                (design gate)  (write gate)  │                         │
                                                              ▼                         ▼
                                              small task ─► dispatch: single lane + reviewer
                                                              (no wave decomposition, no plan gate)
                                          feature/BRD ─► plan gate (skeptic attacks decomposition)
                                                              │
                                                    EXECUTE (fan-out waves)
                                                              │
                                             per-task review gate (skeptic disputes the done-claim)
                                                              │
                                         whole-branch review + skeptic final pass
                                                              │
                                         finish branch (merge/PR) ─► kill the skeptic
```

- **Small task** → single lane + reviewer (or the controller does it) — but it still **branches and spawns the `skeptic` first** (no triage exception for size); it then jumps straight to dispatch, skipping only wave decomposition and the plan gate. The per-task review gate (skeptic disputes the done-claim) and the whole-branch/skeptic final pass still apply.
- **Feature / BRD** → run the full chain. For a BRD too big for one spec, **decompose into sub-projects first** (independent pieces + build order), then run each sub-project through the chain. This is the `brainstorm → writing-plans → subagent-driven-development` flow.

**Gate discipline:** each stage produces an artifact and only advances when its gate passes. Design gate = user/PO approves the spec. Write gate = plan self-review clean. Review gate = reviewer approves the task. Never skip a gate to "save time" — a skipped gate is where the expensive bug hides.

---

## 3. Decomposition — turning work into parallel waves

The controller's first real job. Steps:

1. **List the files/units** the work touches (scout inline first — grep, read structure — before deciding the shape).
2. **Build the dependency graph** between units. What must exist before what.
3. **Group into waves.** A wave = tasks that can run **at the same time** because they touch **disjoint files** and their deps are already met.
4. **Assign lanes by file ownership.** Each lane owns a directory/package; two lanes never edit the same file. The only shared file is usually the lockfile → designate one lane **first-mover** on installs; others re-run install if they race.
5. **Sequence cross-dependencies at the gates**, not inside a wave. If task B needs task A's output, B waits at a gate until A is reviewed.

**Parallelism is only safe on disjoint files.** If two tasks would edit the same file, they are one lane's sequential work, not two lanes. (Worktrees are an escape hatch for true parallel edits, but they cost setup + a merge — avoid unless necessary.)

**Worked shape** (from a real multi-tenant backend):
```
Wave 1: db-schema (api-lane)  ‖  role-capabilities (domain-lane)  ‖  DTOs (contracts-lane)   ← 3 lanes, disjoint
Wave 2: org-CRUD (api-lane, needs schema+DTOs)  ‖  scope-logic (domain-lane)
Wave 3: tenancy-guard (api-lane)  →  capability-guard (needs role map)  →  freeze  →  enrol
```
The front half fans out 3-wide; the back half is an inherent chain (each builds on the last). **Honest rule: fan out where the graph is wide, chain where it's deep. Don't fake parallelism on a dependency chain.**

---

## 4. Agent lifecycle — spawn, reuse, kill

This is where swarms leak resources if you're sloppy (we learned the hard way — zombie agents accumulate across phases).

**Spawn** a lane/reviewer with a **name** = its role (`api-lane`, not `agent-7`). Give it: (1) one line on where the task fits, (2) the brief-file path (its requirements — extract with a brief tool or write it), (3) interfaces/decisions from earlier tasks it can't know, (4) your resolution of any ambiguity, (5) the report-file path + report contract. **Exact values (code, magic strings, signatures) live in the brief file, not pasted into the prompt.**

**Reuse** an existing lane by **messaging it by name** to give it its next task — do NOT spawn a fresh copy. Spawning `api-lane-2` while `api-lane` still lives = two agents in one working tree = file races. If a lane is alive and idle, send it the next brief; only spawn when no lane of that role exists.

**Kill** every agent when its work is done — actually stop it, don't just message "stand down." A "stand down" message leaves the process alive; it becomes a zombie that later auto-picks-up tasks and collides. At each lane's completion and at plan end, **stop the agent**. Periodically audit for zombies and kill any lane/reviewer no longer needed.

**One persistent reviewer** is the exception worth keeping: reuse it across tasks by messaging it, so it accumulates review context — but still kill it at program end.

**The `skeptic` is mandatory, persistent, singular, and non-recursive.** It is spawned at branch time before any dispatch, regardless of task size — a one-line typo fix gets a skeptic too; there is no triage exception, because a rule with a discretionary crack gets widened under time pressure. Message it by name at each gate; never spawn a second one (a duplicate `skeptic` is the same bug as `api-lane-2`). Kill it at program end after its final pass clears. **Sub-controllers do not spawn sub-skeptics at any depth** — a recursing lane's sub-work is gated when the lane's *integrated* diff reaches the top-level skeptic, consistent with the rule that you gate a lane's rolled-up result rather than its leaf agents.

Rules of thumb:
- Confirmed workers are the ones that **produce commits and report** — address those names.
- Before spawning, ask: does a lane of this role already exist and idle? If yes, message it.
- After a phase: list agents, kill everything not needed for the next phase.

### Recursive fan-out — a lane that becomes a sub-controller

A lane isn't limited to building solo. When you hand it a task that is itself **wide** (many disjoint files / independent sub-parts), grant it permission to **spawn its own worker sub-agents** and act as their controller. This is the primary way to go faster on a large task: instead of one lane grinding through 6 files serially, it fans out 6 sub-lanes, gates them, and integrates. Do it **wherever it buys real parallelism.**

How to enable it (all of this goes in the lane's dispatch/brief):
- **Say so explicitly** — a lane recurses only when told: *"You MAY spawn sub-agents via the Agent tool if your task decomposes into disjoint parallel pieces; you become their controller."*
- **The lane inherits the full controller contract, one level down:** partition its own file boundary among sub-lanes (never two on the same file), own integration + the shared package index/lockfile, write sub-briefs as files, **verify every sub-diff**, adversarially review the risky ones, and **kill sub-lanes when done** (zombie audits apply at every level).
- **Depth cap 2 by default** (controller → lane → sub-lane); 3 only when a sub-task is itself clearly wide. **Never recurse down a dependency chain** — deep ≠ wide; that's coordination cost, not speed.
- **Shared caps:** the concurrent-agent limit and token budget are shared across the whole tree. Prefer a few well-scoped sub-lanes to a swarm of tiny ones.
- **The report rolls up:** the lane returns one integrated report (files, tests, sub-review verdicts). You gate the lane's result as a unit — you don't manage its leaf agents.

Rule of thumb: **recurse where the sub-graph is wide, build inline where it's small.** For very large deterministic fan-outs, a Workflow script (loops/conditionals/fan-out in code) beats hand-dispatching sub-lanes.

---

## 5. The review gates — why swarms stay correct

Parallel speed is worthless if it ships bugs. Every task passes **three** checks, and none of them is "tests are green":

1. **Controller verification** — the controller reads the actual diff/files for the load-bearing property (the guard clause, the money math, the auth check). It never trusts a lane's "done" — a green suite + a confident report is an unverified claim until the diff confirms it.
2. **Fresh reviewer** — a subagent that reads the diff **adversarially**: does it match the spec (nothing missing/extra), and is it secure/correct? For security-critical seams, prompt the reviewer to **attack the design** ("can a X do Y they shouldn't?"), and point it at the structural analog of any bug already found.
3. **Skeptic** — the persistent doubter attacks the *claim*, not just the code. Is "done" supported by the diff and actual test output, or is it a confident report? Was the process followed (a red phase in `git log`, not merely green tests at the end)? It carries every earlier objection forward.

Escalation:
- **Per-task review** gates each task. Critical/Important findings → a focused fix dispatch → **re-review the fix** (don't trust the fix either).
- **Whole-branch review** at program end, on the **most capable model**, reads all commits as an integrated whole — it catches cross-task gaps a per-task review structurally can't ("this route has no auth at all", "closed is terminal but the guard only checks frozen").
- **Verify every fix by reading it.** A fix report is a claim.

> This layered review is the single highest-value habit. In practice it repeatedly catches authorization holes that tests + the author + the controller's own first read all passed — because tests prove *behavior*, but only an adversarial reader proves *who-can-do-what*.

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

Model selection for reviewers: scale to the diff's risk. Mechanical diff → cheap model. Subtle auth/concurrency change or the final whole-branch pass → top tier.

---

## 6. Durable state — surviving compaction & handoff

Conversation memory does not survive compaction; a controller that loses its place can re-dispatch completed work (the most expensive failure). So **state lives in files**, not just context:

- **Progress ledger** (`.superpowers/sdd/progress.md` or similar) — one line per task as its review clears: `Task N: complete (commits base..head, review clean)`, plus tracked Minors and cross-task notes. This is the recovery map: after compaction, trust the ledger + `git log` over memory.
- **Brief files + report files** — each task's requirements and each agent's report are files, referenced by path in dispatches. Bulk artifacts move as files, never pasted into prompts (pasted text re-enters context on every later turn).
- **Git commits** — the ground truth. One commit per green task. The ledger names the commits; they exist even when context doesn't remember them.
- **Specs / plans / design / roadmap** — every design decision, plan, and % -to-go-live is a committed doc. Nothing important is in the controller's head only.

**Resume protocol:** on start/after compaction, read the ledger + `git log`; tasks marked complete are done — do not re-dispatch. Resume at the first unmarked task.

---

## 7. Visibility layer — cross-platform (macOS / Linux / Windows), multiplexer-optional

**The orchestration is 100% OS-agnostic.** It is agents + brief/report files + git + a ledger — none of that depends on the operating system or on any terminal multiplexer. So the swarm runs identically on **macOS, Linux, and Windows**. A multiplexer (tmux and friends) is *only* the optional live-viewer for the human; it changes nothing about how the work gets done. **The same amount of work, the same rigor, everywhere — with or without a multiplexer.**

**Capability detection (pick the best available, in this order):**
1. **tmux** — macOS/Linux native; on Windows via WSL. Check `$TMUX` / `command -v tmux`.
2. **zellij** — a modern multiplexer that runs **natively on Windows** as well as macOS/Linux; good default when tmux isn't present. Check `command -v zellij`.
3. **Windows Terminal split panes** — on native Windows without a multiplexer, `wt.exe` can open split panes (`wt split-pane`); or any other multiplexer the machine has (WezTerm, ConEmu tasks, a PowerShell-based splitter — whatever is installed).
4. **Headless (always works, zero deps)** — no multiplexer at all: the **ledger file is the single source of live status**. The human tails it (`tail -f ledger` on POSIX, `Get-Content -Wait ledger` in PowerShell) or asks the controller for a status line. The controller emits a status line to the ledger at every gate ("Wave 1: T1✅ T3✅, releasing T4").

**The pane recipe is the same regardless of which multiplexer wins** — one window, three regions, controller widest:
```
┌──────────────────────────┬─────────────┐
│                          │  status:    │  git log + ledger tail,
│   controller (team-lead) │  refresh 4s │  refreshing on a loop
│      ~70% width          ├─────────────┤
│                          │  free shell │  for the human's own commands
└──────────────────────────┴─────────────┘
```
- **tmux:** `tmux split-window`; status loop `while true; do clear; git log --oneline -10; tail -n5 ledger; sleep 4; done`; detect via `tmux display-message -p`, script via `tmux -S <socket>`.
- **zellij:** `zellij action new-pane`/`--direction`; run the same status loop in the status pane. Works the same on Windows.
- **Windows Terminal:** `wt split-pane -H` / `-V`; status loop in PowerShell: `while ($true) { clear; git log --oneline -10; Get-Content ledger -Tail 5; Start-Sleep 4 }`.
- **Headless:** skip the panes entirely; the loop above is what the human runs (or omits) — the controller still writes every gate to the ledger.

**Rule:** detect → use the best viewer available → otherwise headless. Never block or reduce the work because a multiplexer is missing; the viewer is cosmetics, the ledger is the real record. A `/fan-out ... no tmux` (or a Windows box with nothing installed) runs the exact same swarm, just without the split-screen.

---

## 8. Efficiency principles (the "super efficient by default")

- **Context curation over context dumping.** Hand each agent a brief file + interfaces, not the transcript. The controller stays lean so it can coordinate a long program without drowning.
- **Model tiering.** Transcription tasks (plan has the exact code) → cheapest model. Prose-spec implementation & integration → mid tier. Design, and the final whole-branch review → top tier. Always set the model explicitly; an omitted model silently inherits the most expensive one.
- **Turn-count beats token-price.** Cheapest models take 2–3× the turns on multi-step work; use mid-tier as the floor for reasoning tasks, cheapest only for transcription.
- **Fan out only where the graph is wide.** Wasting agents on a dependency chain adds coordination cost, not speed.
- **Pipeline, don't barrier.** When a later stage only needs one item's prior stage (not all), let items flow independently instead of waiting for the whole wave. (For deterministic orchestration of large fan-outs, a workflow script beats manual dispatch — loops, conditionals, fan-out in code.)
- **Release the next task in parallel with a review** when they touch different files — momentum without collision; batch any review finding as a follow-up fix.
- **Stop idle agents.** Every alive agent is latent cost and collision risk.

---

## 9. Safety & quality invariants (never traded for speed)

- **Never trust "done."** Verify the diff.
- **Never skip the review gate** on anything with an auth/money/data-integrity surface.
- **Never run two agents in the same file/working-tree** concurrently.
- **Never fake a human gate.** Sign-offs (spec approval, UAT, launch) are recorded when the human relays them, never self-approved.
- **The skeptic is not optional and cannot be dismissed silently.** Every run spawns it; every open block is fixed or recorded as a controller override in the ledger. A gate passed without the skeptic's verdict is not a passed gate.
- **Never lose the paper trail.** Ledger + git + committed specs/plans.
- **Adversarial review for authorization.** Prompt reviewers to attack the design, not just check the happy path.
- **Fail closed.** Guards deny on missing context; fixes prefer 4xx over silent success.
- **No spawned agent runs a destructive command without team-lead review — at any level.** Lanes and sub-lanes build, test, and commit their own files. Anything that can lose work or state — `git reset --hard`, `git push -f`, branch/tag deletes, `rm -rf`, `git clean -fdx`, dropping DB tables / migrating down, `TRUNCATE`, overwriting untracked files, killing shared processes, force-installing over a lockfile — is **proposed up to the controller, never executed by the worker**. The controller backs up first (branch/stash), then runs it or relays it to the human. State this limit in every lane/sub-lane brief; a sub-controller enforces it on its own sub-lanes.
- **Destructive ops get a backup first** (branch/stash) and are surfaced, not done silently.

---

## 10. What the controller runs, end to end (checklist)

1. **Triage** the input: one task vs feature vs BRD. Pick the lifecycle depth. **Small task** → single lane + reviewer, no wave decomposition, no plan gate — but steps 3 (branch + spawn skeptic), 7, and 10 still apply, no exceptions.
2. **(feature/BRD)** brainstorm → spec (design gate) → plan (write gate). Decompose a BRD into sub-projects first if it's too big for one spec.
3. **Branch.** Record the base commit. Seed the ledger. **Spawn the `skeptic`** — every run, no exceptions, even a single small task.
4. **Decompose** the plan into waves + lane assignments (disjoint files, dependency-sequenced).
5. **Plan gate:** the `skeptic` attacks the decomposition before dispatch; clear its blocks. Then **viewer:** detect the best available multiplexer (tmux → zellij → Windows Terminal → …); set up the 3-region panes; if none, run **headless** with ledger status. OS-agnostic — macOS/Linux/Windows all supported (see §7).
6. **Dispatch Wave 1** lanes in parallel (named, brief-file-driven, cheap models for transcription).
7. **Per task:** lane reports → controller verifies the diff → fresh reviewer → **`skeptic` disputes the done-claim** → fix loop if needed → **bank in ledger + commit stands**.
8. **Sequence** cross-deps at gates; release parallel tasks where files are disjoint.
9. **Kill** each lane at its completion; audit for zombies between phases.
10. **Whole-branch review** (top model) + **`skeptic` final pass** → batch-fix findings → re-review → kill the `skeptic`.
11. **Finish the branch** (merge/PR per the human's choice) → update the roadmap %.
12. **Report** the outcome to the human in plain terms: what shipped, what's verified, what's tracked.

---

## 11. Two worked examples

**Single task — `/fan-out add a rate-limit to verify-otp`:**
Triage → small. Controller still branches and **spawns the `skeptic`** first (no exceptions for size), then spawns `api-lane` with a brief (the counter logic + a test) — no wave decomposition, no plan gate. Lane reports; controller verifies the diff; one reviewer confirms the brute-force cap actually burns the code; the `skeptic` disputes the done-claim and clears it (the test output backs the claim). Controller banks it in the ledger, kills the lane, and kills the `skeptic`. Minutes, one gate — cleared by both reviewer and skeptic.

**Program — `/fan-out build the org + tenancy backbone per the spec`:**
Brainstorm the org model → spec (design gate) → plan of ~10 tasks (write gate) → branch. Wave 1: `api-lane` (db schema) ‖ `domain-lane` (role→capability map) ‖ `contracts-lane` (DTOs) — 3-wide, disjoint. Then the backend chain (org CRUD → scheme → tenant guard → capability guard → freeze → enrol), each gated. A dedicated security reviewer on the guard seam catches a self-escalation hole; fix + re-review. Whole-branch review (top model) catches an anonymous-route hole; fix + re-review. Kill lanes, finish branch, bump the roadmap. The result: a reviewed, tested, tenant-isolated backbone built with two lanes running in parallel through the wide part.

---

## 12. Turning this into an actual `/fan-out` command

This file is the behavior spec. To make `/fan-out` real:
- Package it as a **skill** (a `SKILL.md` whose body is §0–§10 as instructions the model follows on invocation), placed where the harness discovers skills.
- The skill reads its argument, runs the **triage → lifecycle → decompose → dispatch → gate → finish** loop above, choosing lane count / models / tmux automatically, honoring any optional setup override.
- It composes the existing process skills (brainstorming, writing-plans, subagent-driven-development, requesting-code-review, finishing-a-development-branch) rather than replacing them — `/fan-out` is the orchestrator that drives them at swarm scale.

Ask to wire it up and I'll create the skill from this spec.
