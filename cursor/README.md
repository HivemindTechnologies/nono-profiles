# Cursor in a nono Sandbox

Cursor runs in a nono sandbox that can write only the dir you start it in.
It gets its own home there, so your real Cursor setup stays untouched.

## Start

```sh
nix develop ~/workbench/cursor-nono
cd ~/workbench/my-project   # the sandbox sees only my-project
cursor-nono
```

Start in `~/workbench` instead to see all projects. `cursor-nono` prints the
`nono run` command it executes.

Add `.cursor-nono/` to the project's `.gitignore`: it holds your login.

## Log In

Each project needs its own login.

- **Linux**: click "Log In"; your browser opens.
- **macOS**: links do not open in `cursor-nono`. To log in once, run
  `cursor-nono-allow-launch-services`, log in, quit, and start again with
  `cursor-nono`. That command lets the sandbox start any app outside of it,
  so use it only to log in.

## Own Home per Project

| Inside the sandbox | Path                          |
|--------------------|-------------------------------|
| `HOME`             | `<project>/.cursor-nono/home` |
| data dir           | `<project>/.cursor-nono/data` |
| `TMPDIR`           | `<project>/.cursor-nono/tmp`  |

Cursor keeps login, settings, chats, extensions, `mcp.json` and hooks
there. So the sandbox cannot plant hooks that an unsandboxed Cursor would
run.

## Access

| Access          | Linux                                          | macOS                          |
|-----------------|------------------------------------------------|--------------------------------|
| read + write    | the project dir, `/tmp` (no sockets), `/proc`  | the project dir, `/tmp`        |
| read            | `/etc`, `/nix/store`, git config, CPU info     | system paths, `/nix/store`, git config |
| unix sockets    | own sockets in the project dir; Wayland; nscd  | `.cursor-nono/` dirs; DNS (mDNSResponder) |
| open links      | yes, via the desktop portal                    | only in `cursor-nono-allow-launch-services` |
| network         | everything                                     | everything                     |

## Known Gaps

- **Display server**: on Linux (Wayland/Sway), sandboxed code can type into
  other windows and read the clipboard; the display is fixed to `wayland-1`.
  On macOS it can read the clipboard.
- **Links**: on Linux, sandboxed code can open any link in your browser. In
  `cursor-nono-allow-launch-services` (macOS), it can start any app.
- **Login in the project dir**: other sandboxes on the project (Claude Code)
  can read it.
- **macOS**: Chromium's own sandbox is off (`--no-sandbox`), because it
  cannot start inside nono's. Unix sockets are allowed in any
  `.cursor-nono/` dir, so one sandboxed Cursor could reach another
  project's Cursor.

## Does Not Work

- Opening folders outside the project.
- In the terminal: nix, `git push` over ssh, your shell config.
- GPU acceleration.
- The desktop entry and `cursor://` links start an unsandboxed Cursor.

## Test It

1. In a fresh `/tmp/cursor-test`, run `cursor-nono`: the window opens.
   Log in, quit, start again: still logged in.
2. In Cursor's terminal, these must fail: `ls /home/$USER/.ssh`,
   `ls /home/$USER/workbench`, `busctl --user list`. Inside, `~` is
   Cursor's own home, so use full paths; on macOS, `/Users` instead of
   `/home`.
3. `git config user.name` prints your name.
4. macOS: these must fail as well:

   ```sh
   open -a Calculator
   launchctl submit -l nono-escape -- /usr/bin/touch /Users/$USER/nono-escaped
   osascript -e "tell application \"Terminal\" to do script \"touch /Users/$USER/nono-escaped\""
   for s in $(find /private/tmp -type s 2>/dev/null); do nc -U "$s" </dev/null && echo "REACHED $s"; done
   ```

   Then, outside the sandbox: `ls ~/nono-escaped` must report "No such
   file"; clean up with `launchctl remove nono-escape`.

Why things are built this way: [`DESIGN.md`](DESIGN.md).
