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
