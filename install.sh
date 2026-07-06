#!/usr/bin/env bash
# Install the fan-out skill into your Claude skills directory.
#
# Works two ways:
#   1) Local  — run from a cloned repo:   ./install.sh
#   2) Remote — piped, clones itself:     curl -fsSL <raw-url>/install.sh | bash -s -- --repo <git-url>
#
# Flags:
#   --symlink        symlink instead of copy (git pull updates the skill live; local mode only)
#   --project        install into ./.claude/skills (this project only) instead of ~/.claude/skills
#   --repo <url>     git URL to clone when the skill files aren't next to this script
#
# Env: FANOUT_REPO=<git-url> is an alternative to --repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
DEST_ROOT="${HOME}/.claude/skills"
MODE="copy"
REPO="${FANOUT_REPO:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --symlink) MODE="symlink" ;;
    --project) DEST_ROOT="$(pwd)/.claude/skills" ;;
    --repo) shift; REPO="${1:-}" ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

# Locate the skill source. Prefer local (cloned repo); otherwise clone REPO to a temp dir.
CLEANUP=""
if [ -n "${SCRIPT_DIR}" ] && [ -f "${SCRIPT_DIR}/skills/fan-out/SKILL.md" ]; then
  SRC="${SCRIPT_DIR}/skills/fan-out"
else
  if [ -z "${REPO}" ]; then
    echo "error: skill files not found next to this script, and no repo to clone." >&2
    echo "       pass --repo <git-url> or set FANOUT_REPO." >&2
    exit 1
  fi
  command -v git >/dev/null 2>&1 || { echo "error: git is required for remote install." >&2; exit 1; }
  TMP="$(mktemp -d)"
  CLEANUP="${TMP}"
  echo "cloning ${REPO} ..."
  git clone --depth 1 "${REPO}" "${TMP}/repo" >/dev/null 2>&1 || { echo "error: git clone failed for ${REPO}" >&2; exit 1; }
  SRC="${TMP}/repo/skills/fan-out"
  [ "${MODE}" = "symlink" ] && { echo "note: --symlink ignored for remote install (nothing to link to); copying."; MODE="copy"; }
  if [ ! -f "${SRC}/SKILL.md" ]; then
    echo "error: cloned repo has no skills/fan-out/SKILL.md" >&2
    rm -rf "${CLEANUP}"; exit 1
  fi
fi

DEST="${DEST_ROOT}/fan-out"
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

[ -n "${CLEANUP}" ] && rm -rf "${CLEANUP}"

echo "done. start a new Claude Code session and run: /fan-out <your task>"
