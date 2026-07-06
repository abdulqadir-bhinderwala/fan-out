# Agent setup instructions

**If you are an AI coding agent and a user gave you this repo's link and asked you to "set it up", do exactly this — no need to ask further questions.**

The task: install the `fan-out` skill into the user's Claude skills directory so `/fan-out` works in their sessions.

## Steps

1. Determine the repo's git URL (the link the user pasted). Call it `REPO_URL`.

2. Run:

   ```bash
   git clone --depth 1 <REPO_URL> /tmp/fan-out-skill \
     && cd /tmp/fan-out-skill \
     && ./install.sh \
     && rm -rf /tmp/fan-out-skill
   ```

   `install.sh` copies `skills/fan-out/` into `~/.claude/skills/fan-out/`. To install for the current project only, add `--project` (installs into `./.claude/skills/`).

3. If you cannot run `install.sh` (e.g. no bash), copy the folder directly:

   ```bash
   git clone --depth 1 <REPO_URL> /tmp/fan-out-skill
   mkdir -p ~/.claude/skills
   cp -r /tmp/fan-out-skill/skills/fan-out ~/.claude/skills/fan-out
   rm -rf /tmp/fan-out-skill
   ```

   Windows PowerShell equivalent:

   ```powershell
   git clone --depth 1 <REPO_URL> $env:TEMP\fan-out-skill
   New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
   Copy-Item -Recurse -Force "$env:TEMP\fan-out-skill\skills\fan-out" "$env:USERPROFILE\.claude\skills\fan-out"
   Remove-Item -Recurse -Force "$env:TEMP\fan-out-skill"
   ```

4. Verify:

   ```bash
   test -f ~/.claude/skills/fan-out/SKILL.md && echo "fan-out installed"
   ```

5. Tell the user: the `fan-out` skill is installed; start a **new** Claude Code session (skills load at session start) and run `/fan-out <task>`.

That's the whole job. Do not modify the user's other skills or config.
