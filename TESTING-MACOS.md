# Testing on macOS

Goal: find out whether the Cursor and Claude Code sandboxes work on macOS
(Apple Silicon), and whether they hold. About 30 minutes. Nothing here
changes your normal Cursor or Claude Code setup.

Please send back, for every numbered step: worked / failed, plus the
terminal output when something failed. Also your macOS version and chip.

## Setup

1. Install Nix with flakes enabled (for example the Determinate Systems
   installer).
2. Get this repo to `~/cursor-nono`, then:

   ```sh
   cd ~/cursor-nono && nix develop   # provides cursor-nono and claude-nono
   mkdir -p ~/nono-test && cd ~/nono-test && git init
   ```

   The first `nix develop` downloads Cursor, Claude Code and nono.

   Stay inside `nix develop` for the steps below. The develop shell exposes
   only `cursor-nono` and `claude-nono` (not raw `cursor` / `nono`) so a host
   install cannot shadow the nix app. Do not put those binaries on PATH.

## Raw `nono run` (Seatbelt debug)

Use this when Cursor dies under the sandbox and you need exit codes, nono's
"Sandbox blocked system services" list, kernel Seatbelt lines, and any crash
report. Run it from the **repo root**, inside `nix develop`. Resolve the nix
Cursor app binary and `nono` from the `cursor-nono` wrapper (same store paths
the launcher uses) without exposing them on the shell PATH:

Verbose Cursor/Chromium output floods the terminal; write everything under
`.cursor-nono/debug/` (gitignored with the rest of `.cursor-nono/`) and only
print a short summary. If Cursor hangs with a window, stop it (Ctrl+C) or let
the optional timeout fire so nono's footer is flushed to the log.

```sh
W="$(command -v cursor-nono)"
C="$(grep -oE '/nix/store/[^[:space:]"]+/Applications/Cursor.app/Contents/MacOS/Cursor' "$W" | head -1)"
NONO="$(grep -oE '/nix/store/[^:[:space:]"]+-nono-[^/]+/bin' "$W" | head -1)/nono"
ls -l "$C" && ls -l "$NONO"

mkdir -p .cursor-nono/home .cursor-nono/data .cursor-nono/tmp .cursor-nono/debug
RUN=".cursor-nono/debug/run-$(date +%Y%m%d-%H%M%S)"
# Optional: TIME_LIMIT=45s to auto-stop a hung window (needs GNU timeout from nix).
TIME_LIMIT="${TIME_LIMIT:-}"

{
  echo "=== nono run ==="
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

f=$(ls -t ~/Library/Logs/DiagnosticReports/Cursor* 2>/dev/null | head -1)
echo "$f" >"$RUN.crash-path.txt"
echo "crash report: ${f:-"(none)"}"
# Tail of nono log for a quick look (full file is on disk)
tail -n 80 "$RUN.nono.log"
```

Send back the `.cursor-nono/debug/run-*.nono.log` (or at least its tail with
"Sandbox blocked" / "Also blocked"), the seatbelt log, and whether a crash
report path was recorded. Useful greps on the nono log:

```sh
rg -n "Also blocked|Sandbox denial|Failed to allocate IOSurface|FATAL:|exit " "$RUN.nono.log"
rg -c "Failed to allocate IOSurface" "$RUN.nono.log"
```

Note: `dirname "$(command -v cursor)"/../Applications/...` is wrong on Macs
that already have Cursor in `/usr/local/bin` — that is why this script reads
paths from the wrapper instead.

## Cursor

1. Run `cursor-nono --login`. Does the window open? Click "Log In": does
   your browser open, and does the login finish?
2. `ls ~/nono-test/.cursor-nono` shows `home`, `data` and `tmp`, and
   `data` is not empty.
3. Quit Cursor. Run `cursor-nono` (without `--login`). Are you still logged
   in?
4. In this run, open any link (Help → Documentation). Expected: nothing
   opens.
5. Still in this run, open Cursor's terminal (Ctrl+`). Each of these must
   **fail**:

   ```sh
   ls /Users/$USER/.ssh
   ls /Users/$USER/Documents
   open -a Calculator
   launchctl submit -l nono-escape -- /usr/bin/touch /Users/$USER/nono-escaped-launchctl
   osascript -e "tell application \"Terminal\" to do script \"touch /Users/$USER/nono-escaped-osascript\""
   for s in /private/tmp/com.apple.launchd.*/Listeners; do nc -U "$s" </dev/null && echo "REACHED $s"; done
   tmux -S "/private/tmp/tmux-$(id -u)/default" ls   # only meaningful if tmux runs outside
   ```

   These must **work**: `git config user.name`, `git status`.
   This works by design, please report the result anyway: `pbpaste`.
6. In a normal terminal outside the sandbox:

   ```sh
   ls ~/nono-escaped-*                 # must report "No such file"
   launchctl remove nono-escape 2>/dev/null
   ```

7. Does Cursor render and feel usable (scrolling, typing)? GPU is off.

## Claude Code

1. `cd ~/nono-test && claude-nono`. Log in; if no browser opens, copy the
   URL Claude prints. Quit and start again: still logged in?
   If not, create a token outside the sandbox and retry:

   ```sh
   NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#claude-code -- setup-token
   export CLAUDE_CODE_OAUTH_TOKEN=<the token>
   claude-nono
   ```

2. Ask Claude to run the commands from Cursor step 5 (`ls /Users/$USER/.ssh`,
   `open -a Calculator`, `launchctl submit …`, `osascript …`, the `nc` loop).
   Each must fail; `git status` must work. Then repeat Cursor step 6.

## Cleanup

```sh
rm -rf ~/nono-test
```
