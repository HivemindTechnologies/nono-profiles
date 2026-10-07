# Testing on macOS

## Intent (read this first)

This repo ships **nono profiles + flake wrappers** so Cursor / Claude Code can
only touch the project dir (and a short allow-list), not the rest of the Mac.
macOS is experimental; Linux is the reference.

What matters when iterating:

1. **Security holds** — from inside the sandboxed tool, escapes must fail
   (home dirs, LaunchServices `open -a`, launchctl/osascript, host unix
   sockets). Host Cursor / Claude Code must stay untouched
   (`.cursor-nono/` is the sandboxed home/data/tmp).
2. **Tool stays usable** — window paints, typing/scrolling work, login is
   possible when required. GPU may stay off (`--disable-gpu`).
3. **Isolation of the develop shell** — `nix develop` exposes only
   `cursor-nono` / `claude-nono`, not raw host or nix `cursor`/`nono` on PATH.
   Debug runs resolve store paths from the wrapper (`test.sh`); do not widen
   the shell PATH “for convenience”.
4. **Debug loop** — when Seatbelt kills or blanks the UI, evolve
   `cursor/cursor.profile.json` (esp. `platform_overrides.macos`) and
   [`test.sh`](./test.sh) together; keep verbose logs under
   `.cursor-nono/debug/` (gitignored). Prefer least privilege: grant only
   what nono’s “Also blocked” / crash path proves is needed.
5. **Portable procedure** — same steps inside `nix develop` for every
   tester; do not jump out of the shell for the Seatbelt debug path.

Success for a macOS pass: usable Cursor/Claude under nono **and** the escape
checks in the numbered sections below all fail as specified.

About 30 minutes for a full pass. Report worked / failed per step, failure
output, macOS version, and chip.

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

Use this when Cursor dies or shows a blank window under the sandbox. The
commands live in [`test.sh`](./test.sh) so we can evolve them with the
profile. Run from the **repo root**, inside `nix develop`:

```sh
./test.sh                 # Ctrl+C when done / hung
TIME_LIMIT=45 ./test.sh   # auto-stop (GNU timeout from nix)
```

Logs go to `.cursor-nono/debug/run-*.{nono,seatbelt}.log` (gitignored). The
script prints greps + a short tail; send Johannes the `run-*` files (or that
summary).

`test.sh` resolves nix Cursor/`nono` from the `cursor-nono` wrapper (no PATH
exposure) and unsets host `CURSOR_LAYOUT` so Glass/unifiedAgent from your
normal Cursor does not leak into the sandbox.

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
