#!/usr/bin/env bash
# Install the fan-out skill into your Claude skills directory.
# Usage: ./install.sh [--symlink] [--project]
#   --symlink   symlink instead of copy (git pull updates the skill live)
#   --project   install into ./.claude/skills (this project only) instead of ~/.claude/skills

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills/fan-out"
DEST_ROOT="${HOME}/.claude/skills"
MODE="copy"

for arg in "$@"; do
  case "$arg" in
    --symlink) MODE="symlink" ;;
    --project) DEST_ROOT="$(pwd)/.claude/skills" ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

DEST="${DEST_ROOT}/fan-out"

if [ ! -f "${SRC}/SKILL.md" ]; then
  echo "error: ${SRC}/SKILL.md not found — run from the repo root." >&2
  exit 1
fi

mkdir -p "${DEST_ROOT}"

if [ -e "${DEST}" ] || [ -L "${DEST}" ]; then
  echo "found existing ${DEST} — replacing."
  rm -rf "${DEST}"
fi

if [ "${MODE}" = "symlink" ]; then
  ln -s "${SRC}" "${DEST}"
  echo "symlinked fan-out -> ${DEST}"
else
  cp -r "${SRC}" "${DEST}"
  echo "installed fan-out -> ${DEST}"
fi

echo "done. start a new Claude Code session and run: /fan-out <your task>"
