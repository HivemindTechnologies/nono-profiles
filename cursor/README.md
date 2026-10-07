# Cursor in a nono Sandbox

```sh
cd ~/workbench/my-project   # per project: sees only my-project
cd ~/workbench              # broad: sees all projects
cursor-nono                 # from `nix develop ~/workbench/cursor-nono`
```

`cursor-nono` prints the `nono run` command it executes.

Add `.cursor-nono/` to the project's `.gitignore`. It holds your login.

Linux and macOS are tested.

## Own Home per Project

| Inside the sandbox | Path                          |
|--------------------|-------------------------------|
| `HOME`             | `<project>/.cursor-nono/home` |
| data dir           | `<project>/.cursor-nono/data` |
| `TMPDIR`           | `<project>/.cursor-nono/tmp`  |

Cursor keeps login, settings, chats, extensions, `mcp.json` and hooks
there. Your real Cursor data stays untouched, so the sandbox cannot plant
hooks that an unsandboxed Cursor would run. Each project needs its own
login.

The launcher (`flake.nix`) creates these dirs. Cursor does not create
`TMPDIR` itself: on macOS, it did not start without it.

## Opening Links

- **Linux**: the launcher (`flake.nix`) runs `xdg-dbus-proxy` at
  `.cursor-nono/bus`. It passes on only the desktop portal's `OpenURI` call
  (plus read-only `Introspect`), which opens the link in your default
  browser. Everything else on D-Bus stays blocked.
- **macOS**: there is no narrow way, so links do not open. To log in once,
  copy the command `cursor-nono` prints and add `--allow-launch-services`
  after `nono run`. This lets the sandbox use LaunchServices, which opens
  links but can also start any app outside the sandbox. Quit Cursor after
  login and start it again with `cursor-nono`.

nono's own `open_urls` does not work for Cursor: on Linux nono deadlocks
when its link helper runs under `af_unix_mediation`, and on macOS Electron
opens links through LaunchServices, not through nono's helper.

## Why `--verbose`

The profile passes `--verbose`, so `cursor` stays in the foreground until
Cursor exits (and prints its log). Without it, `cursor` exits at once;
`--wait` returns when the first window closes, e.g. after login. Either way
nono exits too, and with it the supervisor that approves socket calls:
Cursor then shows a white window and dies.

On macOS the launcher skips `cursor` and runs
`Cursor.app/Contents/MacOS/Cursor` directly: `cursor` starts the app through
`open` (LaunchServices), which nono blocks (error -54) or, with
`--allow-launch-services`, which starts Cursor outside the sandbox.

## Rate Limit on Sockets (Linux)

nono allows at most 5 socket `connect`/`bind` calls at once, refilled at
10 per second; further calls fail with "operation not permitted". The
profile sets `DBUS_SYSTEM_BUS_ADDRESS=disabled:`, so Chromium skips 5
system-bus attempts at startup.

## Access

| Access          | Linux                                          | macOS                          |
|-----------------|------------------------------------------------|--------------------------------|
| read + write    | the project dir, `/tmp` (no sockets), `/proc`  | the project dir, `/tmp`        |
| read            | `/etc`, `/nix/store`, git config, CPU info     | system paths, `/nix/store`, git config |
| unix sockets    | own sockets in the project dir; Wayland; nscd  | `.cursor-nono/` dirs; DNS (mDNSResponder) |
| D-Bus / LaunchServices | only the portal's `OpenURI`             | only for login (see above)     |
| network         | everything                                     | everything                     |

## Shortcuts

- **Display server**: on Linux (Wayland/Sway), sandboxed code can type into
  other windows and read the clipboard; the display is fixed to `wayland-1`.
  On macOS it can read the clipboard.
- **Links**: sandboxed code can open any link in your browser (Linux), or
  any app during the login run (macOS).
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
- macOS: nono blocks the keychain, so the login may not survive a restart.

## Test It

1. In a fresh `/tmp/cursor-test`, run `cursor-nono`: the window opens.
   Log in (see "Opening Links"), quit, start again: still logged in.
2. In Cursor's terminal, these must fail: `ls /home/$USER/.ssh`,
   `ls /home/$USER/workbench`, `busctl --user list` (macOS: `/Users/$USER`).
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

For a shell in the sandbox, use `nono run --profile cursor/cursor.profile.json
-- sh -c sh` (`sh -c` ignores the Cursor flags the profile appends).
