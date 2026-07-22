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

## Four roles (always)

| Role | Who | Does | Never |
|---|---|---|---|
| **Controller** | You (main session) | Decompose, spawn/steer lanes, gate reviews, integrate, keep ledger | Write feature code (stay free to coordinate) |
| **Lane** | Spawned subagent, named by domain (`api-lane`, `ui-lane`, `spa-lane`, `infra-lane`, `domain-lane`) | Build one task in **its own files**, TDD, commit, self-review, report. If the task is large + disjoint, **sub-fan-out** its own worker sub-agents (see *Recursive fan-out*) | Touch another lane's files; approve itself |
| **Reviewer** | Spawned subagent, fresh-per-task or persistent-reused | Read diff adversarially, verify spec + security, return verdict | Write code; rubber-stamp |
| **Skeptic** | One persistent subagent named `skeptic`, spawned at branch time before any dispatch, killed at program end | Attack the plan before dispatch, audit skill compliance, dispute every claim of done — blocking only on evidence | Write code; block without evidence; be spawned twice |

**Skeptic ≠ Reviewer.** The reviewer is fresh per task and reads one diff for correctness and security. The skeptic is **persistent and remembers** — it goes at *claims, process, and plan shape* across the whole program. That memory is why it can't be folded into the reviewer.

Your leverage is **curating context**: each agent gets a hand-built brief *file*, not session history.

## The loop (run this)

1. **Triage** the input: one small task vs feature vs BRD → pick lifecycle depth.
   - **Small task** → single lane + reviewer (or do it yourself). Still do step 3 (branch + **spawn the `skeptic`**), then jump to step 5(b) — skipping only step 4 and the step-5(a) plan gate. **Every other step applies unchanged.**
   - **Feature / BRD** → run the process chain first (step 2).
2. **Process chain (feature/BRD only):** `superpowers:brainstorming` → spec (design gate: user/PO approves) → `superpowers:writing-plans` → plan (write gate: self-review clean). Decompose a too-big BRD into sub-projects first (independent pieces + build order), each through its own chain. Then `superpowers:subagent-driven-development` drives execution — /fan-out orchestrates these skills at swarm scale, it doesn't replace them.
3. **Branch.** Record the base commit. Seed the ledger (`.superpowers/sdd/progress.md`). **Spawn the `skeptic`** — every run, no exceptions, even a one-line task — with the evidence bar verbatim, its report-file path (`.superpowers/sdd/skeptic.md`), the verdict contract (`VERDICT: PASS | BLOCK` / `BLOCKS: [severity] evidence → the claim it refutes` / `MINORS: unevidenced concerns (tracked, non-gating)`), and an explicit **mid-tier model** (top tier for the final pass).
4. **Decompose into waves** (see below).
5. **Plan gate + viewer:**
   - **(a) Plan gate (feature/BRD):** send the wave decomposition to the `skeptic` before dispatching. It attacks non-disjoint files, faked parallelism on a dependency chain, missing requirements, unstated failure modes. Clear its blocks.
   - **(b) Viewer:** detect best available multiplexer → set up panes; else headless (see below).
6. **Dispatch a wave** of lanes in parallel — named, brief-file-driven, model-tiered. **Grant capable lanes permission to sub-fan-out** when their task is large and internally disjoint (see *Recursive fan-out*).
7. **Per task gate:** lane reports → **you verify the actual diff** → fresh reviewer (adversarial) → **`skeptic` disputes the done-claim and audits skill compliance** → fix loop if Critical/Important → **bank in ledger + commit stands**.
8. **Sequence** cross-deps at gates; release parallel tasks where files are disjoint.
9. **Kill** each lane at completion; audit for zombies between phases.
10. **Whole-branch review** (top model, once) + **`skeptic` final pass** (it carries every earlier objection) → batch-fix findings → re-review.
11. **Finish the branch** (`superpowers:finishing-a-development-branch`, merge/PR per human) → update roadmap % → **kill the `skeptic`** (program end).
12. **Report** to the human plainly: what shipped, what's verified, what's tracked, **and every `OVERRIDE` line from the ledger — a skeptic block bypassed is a decision the human must see.**

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
- **One persistent reviewer** is the one *optional* long-lived agent (the `skeptic` is the mandatory one) — reuse accumulates review context; still kill it at program end.
- **The `skeptic` is always persistent, never duplicated, never inherited.** One per run, spawned at branch time before any dispatch, regardless of task size, messaged by name for every gate, killed at program end. **Sub-controllers do not spawn sub-skeptics** — a recursing lane's work is gated when its *integrated* diff reaches the top-level skeptic, as one unit.

## Recursive fan-out — lanes may spawn their own sub-lanes

When a lane's task is itself **large and internally decomposable** (many disjoint files / independent sub-parts), let the lane act as a **sub-controller**: it splits its task into sub-briefs, spawns its own worker sub-agents in parallel (the Agent tool), gates + integrates them, then reports up. **Recurse wherever the sub-graph is wide** — it's the main lever for going faster on big tasks. A lane doesn't recurse unless you grant it.

Put the grant + guardrails in the lane's brief/prompt when you enable it:

- **Enable explicitly.** In the dispatch, say: *"You MAY spawn your own sub-agents if your task decomposes into disjoint parallel pieces; you then act as their controller — verify each sub-diff, kill them when done, report the integrated result."* Prefer this **wherever it buys real parallelism**.
- **Same disjoint-files rule, one level down.** The lane partitions *its own* file boundary among sub-lanes; two sub-lanes never touch the same file. The lane owns integration + any shared file (its package's index/lockfile).
- **A sub-controller runs the same diff-verification and review gates — but spawns no sub-skeptic:** it verifies each sub-agent's actual diff, reviews risky sub-diffs adversarially, and does **not** pass unverified sub-work upward. Skipping its own gates is as unsafe as a controller skipping them.
- **Depth cap: 2 levels by default** (controller → lane → sub-lane). Go to 3 only when a sub-task is itself clearly wide. **Never recurse on a dependency chain** (deep, not wide) — that adds coordination cost, not speed.
- **Shared budget.** The concurrent-agent cap is shared across the whole tree; every live agent is cost + collision risk. Prefer a few well-scoped sub-lanes over many tiny ones. Kill sub-lanes at their completion (zombie audits apply at every level).
- **Report contract unchanged upward:** the lane returns one report (files, test output, sub-review verdicts) as if it did the work itself — you gate the lane's integrated result, not each leaf agent.

Rule of thumb: **recurse where the sub-graph is wide, build inline where it's small.** Lane with 5 disjoint files → sub-fan-out. Lane with one file → just build it.

## Review gates — why swarms stay correct

Parallel speed is worthless if it ships bugs. Every task passes **three** checks; none of them is "tests are green":

1. **Controller verification** — you read the actual diff for the load-bearing property (the guard clause, the money math, the auth check). A green suite + confident report is an unverified claim until the diff confirms it.
2. **Fresh reviewer** — a subagent reads the diff **adversarially**: matches spec (nothing missing/extra), secure/correct. For auth/money/data seams, prompt it to **attack the design** ("can a X do Y they shouldn't?") and point it at the structural analog of any bug already found.
3. **Skeptic** — the persistent doubter disputes the *claim*, not just the code: is "done" supported by the diff and the test output, or is it a confident report? Was the process actually followed (TDD red phase in `git log`, not just green tests)? It carries memory across tasks — a lane that overstated once gets more scrutiny later.

**The skeptic blocks, but only on evidence.** A `BLOCK` is valid only when it cites one of: `file:line` + why it's wrong; a concrete failing input or repro; a spec line contradicted by code; or a missing artifact that should exist. Anything weaker auto-downgrades to a **tracked Minor** — logged in the ledger, non-gating. Say this in its dispatch so it self-filters instead of you arguing findings down. Without this bar, a skeptic with blocking power deadlocks the swarm on vibes.

It reports to a file:

`VERDICT: PASS | BLOCK` / `BLOCKS: [severity] evidence → the claim it refutes` / `MINORS: unevidenced concerns (tracked, non-gating)`

**Any open BLOCK gates** — Critical and Important both stop the gate; severity only sets fix urgency. Two exits: **fix** → focused dispatch → **the skeptic re-checks its own block** (not the reviewer — persistence is the point), or **override** → allowed, but it costs a ledger line, never a silent bypass:

`OVERRIDE <gate>: <block> — reason: <why> — controller`

where `<gate>` is `T<n>` for a task gate, `PLAN` for the plan gate, `BRANCH` for the whole-branch gate. Example: `OVERRIDE T4: no red-phase commit — reason: single-line config change, no behavior — controller`

- **Per-task review** gates each task. Critical/Important → focused fix dispatch → **re-review the fix** (don't trust it either).
- **Whole-branch review** at program end, **top model**, reads all commits as a whole — catches cross-task gaps a per-task review structurally can't.
- **Verify every fix by reading it.** Scale reviewer model to the diff's risk.

> This layered review is the single highest-value habit — it repeatedly catches authorization holes that tests + author + your own first read all passed, because tests prove *behavior* but only an adversarial reader proves *who-can-do-what*.

## Durable state — surviving compaction

Conversation memory does not survive compaction; a controller that loses its place can re-dispatch completed work (most expensive failure). **State lives in files:**

- **Progress ledger** — one line per task as its review clears: `Task N: complete (commits base..head, review clean, skeptic PASS)`, plus tracked Minors + cross-task notes. Recovery map after compaction: trust ledger + `git log` over memory.
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
- **Model tiering** — transcription (plan has exact code) → cheapest; prose-spec implementation + integration → mid; design + final whole-branch review → top; the persistent `skeptic` → mid tier, top tier for its final pass. **Always set the model explicitly** (omitted = inherits most expensive).
- **Turn-count beats token-price** — cheapest models take 2–3× the turns on multi-step work; mid-tier is the floor for reasoning tasks.
- **Fan out only where the graph is wide.** **Pipeline, don't barrier** — let items flow when a later stage needs one item's prior stage, not the whole wave. For large deterministic fan-outs, a Workflow script beats manual dispatch.
- **Release the next task in parallel with a review** when files differ. **Stop idle agents** — every alive agent is latent cost + collision risk — **except the `skeptic` and any persistent reviewer, which are idle between gates by design and live until program end.**

## Safety invariants (never traded for speed)

- Never trust "done" — verify the diff. Never skip the review gate on an auth/money/data-integrity surface.
- Never run two agents in the same file/working-tree concurrently — **at any level.** Recursion follows the same rules everywhere: disjoint files, verify-the-diff, kill-when-done, depth cap.
- Never fake a human gate — sign-offs (spec approval, UAT, launch) are recorded when the human relays them, never self-approved.
- **The `skeptic` is not optional and cannot be dismissed silently.** Every run spawns it; every open block is fixed or recorded as a controller override in the ledger. A gate passed without the skeptic's verdict is not a passed gate.
- Never lose the paper trail (ledger + git + committed specs/plans).
- Adversarial review for authorization. Fail closed (guards deny on missing context; prefer 4xx over silent success).
- **No spawned agent runs a destructive command without team-lead (controller) review** — at any level. Lanes and sub-lanes build, test, and commit their own files; anything that can lose work or state (`git reset --hard`, `git push -f`, branch/tag deletes, `rm -rf`, dropping DB tables / migrations down, truncate, overwriting untracked files, killing shared processes, force-installing over a lockfile) is **proposed up to the controller, not executed**. The controller reviews, takes a backup first (branch/stash), and either runs it or relays it to the human. Put this limit in every lane/sub-lane brief. Sub-controllers enforce it on their own sub-lanes.
- Destructive ops get a backup first (branch/stash) and are surfaced, not done silently.

## Field lessons — earned, not theorised

Each of these cost real time on a real programme. They are ordered by how often they recur.

### Verify in the world, never in the runner

A tool reporting success is evidence that **everything the tool could see** succeeded — not that your
change landed. Ask the system what exists.

- A migration runner reported *"up to date — verified 22 migrations"* and applied **nothing**: it ran
  from a built image, not the working tree. Count the ledger; look for the object.
- A container was three days stale while its health check was green. Every route 404'd against source
  that was committed and correct. **Probe the endpoint, don't read the code.**
- Rebuilding ONE service silently applied a lane's uncommitted migration to the owner's live database —
  `depends_on: migrate` ran the whole chain. **Check for uncommitted migrations before any rebuild.**

### A green suite is not a working product

Reserve real suspicion for the gap between "tests pass" and "it works".

- **jsdom has no layout engine.** Five layout defects shipped green: a page cap 48px short of its own
  breakpoint, a missing `mx-auto` leaving 656px dead, a 1px-wide table column, a crashed route, a
  stranded panel. **Measure in a real browser.** Report the numbers, not "looks right".
- **A mocked client cannot see a contract the mock does not honour.** Four defects shipped because the
  mock answered more agreeably than the server: a `200` with an empty body that the client tried to
  parse (every successful save reported failure), a `.strict()` rejection the mock never performed
  (**every save was a silent no-op**), an uncontracted response shape. **Walk each route a user's data
  passes through ONCE against the running system before the phase closes.** All four surfaced in a
  single save→leave→return loop.
- **A test can assert the right thing about the wrong scenario.** A lane's absent-vs-empty test
  survived the backwards mutation because nothing in the suite ever reached the state it described.
- **Mutation-check anything load-bearing, and confirm the tests EXECUTED** — not merely that they were
  red. A mutation that only breaks compilation proves nothing; a malformed mutation that changes no
  behaviour reports SURVIVED, indistinguishable from a real survival.
- **A killed mutation run is an unknown state, not a no-op.** A timeout left the mutation LIVE in the
  tree because the restore sat in a `finally` that never ran. **Diff against a known-good copy before
  committing after any interrupted run.**

### Managing lanes

- **Commit per completed piece, never once at the end.** A lane lost two hours to an API crash with
  everything uncommitted. The brief survived; the work did not.
- **State lives in files.** When a lane dies, its approved design must be recoverable — fold the plan
  into the brief and commit it, so a replacement inherits the thinking rather than re-deriving it.
- **A lane that reports idle without starting, twice, gets replaced — not prodded.** Re-sending costs
  a round trip each time and the outcome does not change.
- **Kill lanes when done, and audit for zombies.** A crashed lane still showed as running hours later;
  two more survived a context compaction unnoticed. Enumerate live agents periodically.
- **If the human is using the app, the working tree IS the running application.** Dev servers serve it.
  A half-finished rename put a stack trace in front of the owner. Order edits so the tree always
  compiles: add the new shape, migrate references, remove the old one. **Never remove first.**

### Controller discipline

The controller's failures are the expensive ones, because everything downstream inherits them.

- **Never write an id, a filename or a test name you have not looked at.** Fabricated two issue ids in
  one session by trusting a create command's output that never printed them — the exact failure being
  corrected in lanes at the time.
- **Re-check `git log` before accusing a lane of idling.** Messages cross. A stale snapshot produced an
  unfair correction that had to be retracted.
- **Reports go stale the moment they are written.** Lanes repeatedly inherited claims from each other's
  reports that were true when written and false when read — an unapplied migration, a missing route.
  Route the *finding*, and re-verify the *state*.
- **Ambiguity flagged by a lane is worth more than code.** Lanes that stopped to ask — a rule they
  believed wrong, a mirror they could not avoid, a gate change outside their brief — each surfaced a
  real defect. **Reward flagging; never punish it with more scope.**
- **When a lane refuses on principle, check the principle before overriding.** One refused its task
  arguing the rule was wrong. It was right; the task was reverted.

### Patterns worth naming across a programme

When the same defect appears three times, stop filing bugs and name the habit:

- **A rule enforced on the READ side and absent on the WRITE side.** Three instances in one phase: an
  offer that checked a column the create gate did not, a value displayed but not enforced, an account
  type offered only under a condition the POST accepted without. **When a rule is added to a read
  route, ask which write route must also refuse it.**
- **Two layers each holding a default disagree silently.** A client restating a server default hid the
  owner's configured value. Constants belong in the one package both sides already share.
- **An ORM defeats a column-level GRANT by naming every column** — and `.returning()` silently requires
  SELECT on a table that deliberately grants none. **Fix the call; never widen the grant.** Widening
  makes the symptom vanish and dissolves the protection.
- **Two permissive RLS policies are one gate with the union of both openings.**
