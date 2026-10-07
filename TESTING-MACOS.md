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

Success for a macOS pass: usable Cursor/Claude under nono **and** the escape
checks in the numbered sections below all fail as specified.

About 30 minutes for a full pass. Report worked / failed per step, failure
output, macOS version, and chip.

## Setup

1. Install Nix with flakes enabled (for example the Determinate Systems
   installer).
2. Get this repo to `~/cursor-nono`, then:

   ```sh
   cd ~/cursor-nono && nix develop   # cursor-nono, claude-nono; plain nono, claude, cursor
   mkdir -p ~/nono-test && cd ~/nono-test && git init
   ```

   The first `nix develop` downloads Cursor, Claude Code and nono.

   Stay inside `nix develop` for the steps below.

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
