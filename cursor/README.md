# Cursor in a nono Sandbox

```sh
cd ~/workbench/my-project   # per project: sees only my-project
cd ~/workbench              # broad: sees all projects
cursor-nono                 # from `nix develop ~/workbench/cursor-nono`
cursor-nono --login         # macOS only: first start, to log in
```

Add `.cursor-nono/` to the project's `.gitignore`. It holds your login.

Linux is tested. macOS is **experimental**: untested so far, see
`../TESTING-MACOS.md`.

## Own Home per Project

| Inside the sandbox | Path                          |
|--------------------|-------------------------------|
| `HOME`             | `<project>/.cursor-nono/home` |
| data dir           | `<project>/.cursor-nono/data` |
| `TMPDIR`           | `<project>/.cursor-nono`      |

Cursor keeps login, settings, chats, extensions, `mcp.json` and hooks
there. Your real Cursor data stays untouched, so the sandbox cannot plant
hooks that an unsandboxed Cursor would run. Each project needs its own
login.

Cursor creates these dirs itself. nono grants only paths that exist, but the
only grant here is the project dir.

## Opening Links

- **Linux**: the launcher (`flake.nix`) runs `xdg-dbus-proxy` at
  `.cursor-nono/bus`. It passes on only the desktop portal's `OpenURI` call
  (plus read-only `Introspect`), which opens the link in your default
  browser. Everything else on D-Bus stays blocked.
- **macOS**: there is no narrow way. `cursor-nono --login` lets the sandbox
  use LaunchServices, which opens links but can also start any app outside
  the sandbox. Use it only to log in; without it, links do not open.

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
`open` (LaunchServices), which nono blocks (error -54) or, with `--login`,
which starts Cursor outside the sandbox.

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
| D-Bus / LaunchServices | only the portal's `OpenURI`             | only with `--login`            |
| network         | everything                                     | everything                     |

## Shortcuts

- **Display server**: on Linux (Wayland/Sway), sandboxed code can type into
  other windows and read the clipboard; the display is fixed to `wayland-1`.
  On macOS it can read the clipboard.
- **Links**: sandboxed code can open any link in your browser (Linux), or
  any app during `--login` (macOS).
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

## Test It (Linux)

1. In a fresh `/tmp/cursor-test`, run `cursor-nono`:
   the window opens. "Log In" opens your browser.
2. In the terminal, these must fail: `ls /home/$USER/.ssh`,
   `ls /home/$USER/workbench`, `busctl --user list`.
3. `git config user.name` prints your name.

For a shell in the sandbox, use `nono run --profile cursor/cursor.profile.json
-- sh -c sh` (`sh -c` ignores the Cursor flags the profile appends).
