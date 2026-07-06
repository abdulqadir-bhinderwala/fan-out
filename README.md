# fan-out

**Agent-swarm orchestration for Claude Code.** Turn one Claude session into a small software company: a **controller** that decomposes work, spawns named **specialist lane agents** to build in parallel, gates every result through **adversarial reviewers**, and keeps a **durable ledger** — so one task or a whole BRD ships fast without losing rigor.

Works with or without `tmux`. Cross-platform: macOS, Linux, Windows.

---

## What it does

You type:

```
/fan-out <task | spec/BRD path | description> [optional swarm setup]
```

The skill triages the work, decomposes it into **file-disjoint waves**, fans out lanes where the dependency graph is wide, chains where it's deep, and gates every task through a fresh adversarial reviewer before banking it in a durable ledger.

| Example | What happens |
|---|---|
| `/fan-out add rate-limiting to the login endpoint` | One small task → 1 lane + 1 reviewer. Minutes. |
| `/fan-out build the reporting module per docs/specs/reporting.md` | A feature → planned, fanned out by file boundary, each piece reviewed. |
| `/fan-out ship the whole BRD at docs/BRD.docx` | A program → decomposed into sub-projects, each run brainstorm → spec → plan → parallel build → review → finish. |

Optional setup overrides in plain English: `... with 3 backend lanes and a security reviewer`, `... no tmux`, `... cheapest models`, `... don't touch payments`, `... run to completion, don't check in`. With no overrides, the controller decides lane count, model tiers, review depth, and viewer itself.

---

## Install

This is a **plain skills repo** — clone it and drop the `fan-out` folder into your Claude skills directory.

### Quick install (script)

```bash
git clone https://github.com/<you>/fan-out.git
cd fan-out
./install.sh          # copies skills/fan-out into ~/.claude/skills/
```

### Manual install

```bash
git clone https://github.com/<you>/fan-out.git
cp -r fan-out/skills/fan-out ~/.claude/skills/fan-out
```

Or symlink it (so `git pull` updates the skill live):

```bash
ln -s "$(pwd)/fan-out/skills/fan-out" ~/.claude/skills/fan-out
```

**Project-scoped** (only for one repo instead of globally): copy into `.claude/skills/` inside that project.

### Windows (PowerShell)

```powershell
git clone https://github.com/<you>/fan-out.git
Copy-Item -Recurse fan-out\skills\fan-out "$env:USERPROFILE\.claude\skills\fan-out"
```

---

## Verify

Start a new Claude Code session and run:

```
/fan-out add a rate-limit to verify-otp
```

If the skill loaded, Claude announces it's using **fan-out** and runs the triage → decompose → dispatch → gate loop. You can also confirm the file exists:

```bash
ls ~/.claude/skills/fan-out/SKILL.md
```

---

## What's in the repo

```
skills/fan-out/
  SKILL.md               # the operational loop Claude follows on /fan-out
  reference/PLAYBOOK.md  # full playbook — depth on every step
install.sh               # copies the skill into ~/.claude/skills/
LICENSE                  # MIT
```

`SKILL.md` is the operational loop (loaded when the skill triggers). `reference/PLAYBOOK.md` is the deep reference the skill reads on demand — decomposition into waves, agent lifecycle (spawn/reuse/kill, zombie audits), the two-layer review gates, durable state that survives compaction, and the cross-platform visibility layer.

---

## The core idea

Most AI coding is one agent doing one thing at a time. A swarm wins when work is **decomposable** and **file-disjoint**. Three roles, always:

- **Controller** (your main session) — decomposes, spawns/steers lanes, gates reviews, keeps the ledger. Never writes feature code itself, so it stays free to coordinate.
- **Lane** (spawned subagent, named by domain: `api-lane`, `ui-lane`, `infra-lane`…) — builds one task in **its own files**, TDD, commits, self-reviews, reports. Never touches another lane's files.
- **Reviewer** (spawned fresh per task, or one persistent reviewer reused) — reads the diff **adversarially**, verifies spec + security, returns a verdict. Never rubber-stamps.

Parallel speed is worthless if it ships bugs, so **every task passes two checks**: the controller reads the actual diff for the load-bearing property, then a fresh reviewer attacks it. A whole-branch review on the top model catches cross-task gaps at the end.

Full detail lives in [`skills/fan-out/reference/PLAYBOOK.md`](skills/fan-out/reference/PLAYBOOK.md).

---

## License

MIT — see [LICENSE](LICENSE).
