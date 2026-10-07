#!/usr/bin/env bash
# Raw nono + Cursor Seatbelt debug. Run from repo root inside `nix develop`.
# Logs land in .cursor-nono/debug/ (gitignored). Evolve this file as we learn.
#
# Usage:
#   ./test.sh              # run until you Ctrl+C or Cursor exits
#   TIME_LIMIT=45 ./test.sh
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v cursor-nono >/dev/null; then
  echo "cursor-nono not on PATH. Enter the flake shell first: nix develop" >&2
  exit 1
fi

W="$(command -v cursor-nono)"
C="$(grep -oE '/nix/store/[^[:space:]"]+/Applications/Cursor.app/Contents/MacOS/Cursor' "$W" | head -1)"
NONO="$(grep -oE '/nix/store/[^:[:space:]"]+-nono-[^/]+/bin' "$W" | head -1)/nono"
ls -l "$C" && ls -l "$NONO"

mkdir -p .cursor-nono/home .cursor-nono/data .cursor-nono/tmp .cursor-nono/debug
RUN=".cursor-nono/debug/run-$(date +%Y%m%d-%H%M%S)"
# Optional: TIME_LIMIT=45 to auto-stop a hung window (GNU timeout from nix).
TIME_LIMIT="${TIME_LIMIT:-}"

# Host Cursor often exports CURSOR_LAYOUT=glass|unifiedAgent; that leaks into
# the sandbox (env passthrough) and can leave a blank Glass window. Drop it
# for this diagnostic so we exercise the classic IDE path.
unset CURSOR_LAYOUT || true

{
  echo "=== nono run ==="
  echo "RUN=$RUN"
  echo "TIME_LIMIT=${TIME_LIMIT:-"(none; Ctrl+C to stop)"}"
  echo "CURSOR_LAYOUT=${CURSOR_LAYOUT-<unset>}"
  if [[ -n "$TIME_LIMIT" ]]; then
    timeout --signal=INT --kill-after=5 "$TIME_LIMIT" \
      "$NONO" run -v --profile cursor/cursor.profile.json -- "$C"
  else
    "$NONO" run -v --profile cursor/cursor.profile.json -- "$C"
  fi
  echo "exit $?"
} >"$RUN.nono.log" 2>&1
echo "wrote $RUN.nono.log"

log show --last 2m --style compact --predicate 'sender == "Sandbox"' \
  | grep -i cursor | head -50 >"$RUN.seatbelt.log" || true
echo "wrote $RUN.seatbelt.log ($(wc -l <"$RUN.seatbelt.log") lines)"

f=$(ls -t ~/Library/Logs/DiagnosticReports/Cursor* 2>/dev/null | head -1 || true)
echo "${f:-}" >"$RUN.crash-path.txt"
echo "crash report: ${f:-"(none)"}"

echo "=== greps ==="
rg -n "Also blocked|Sandbox denial|Failed to allocate IOSurface|FATAL:|window reported ready|exit " \
  "$RUN.nono.log" || true
echo "IOSurface fails: $(rg -c "Failed to allocate IOSurface" "$RUN.nono.log" || echo 0)"
echo "=== tail ==="
tail -n 80 "$RUN.nono.log"
echo "RUN_PREFIX=$RUN"
