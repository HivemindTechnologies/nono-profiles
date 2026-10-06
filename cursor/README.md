# Cursor in a nono Sandbox

```sh
cd ~/workbench/my-project   # per project: sees only my-project
cd ~/workbench              # broad: sees all projects
nix run ~/workbench/cursor-nono
```

Add `.cursor-nono/` to the project's `.gitignore`. It holds your login.

## Own Home per Project

Inside the sandbox, `HOME` is `<project>/.cursor-nono/home` and `TMPDIR` is
`<project>/.cursor-nono`. Cursor keeps login, settings, extensions, chats,
`mcp.json` and hooks there. Your real `~/.cursor` stays untouched, so the
sandbox cannot plant hooks that an unsandboxed Cursor would run. Each
project needs its own login.

## Opening Links

The launcher (`flake.nix`) runs `xdg-dbus-proxy` next to the sandbox, at
`.cursor-nono/bus`. It passes on only one D-Bus call: the desktop portal's
`OpenURI`, which opens a link in your default browser. Everything else on
D-Bus stays blocked. Inside, `xdg-open` uses the portal
(`NIXOS_XDG_OPEN_USE_PORTAL=1`).

nono's own `open_urls` does not work here: nono 0.68 deadlocks when its
link helper runs under `af_unix_mediation`.

## Why `--verbose`

The profile passes `--verbose`, so `cursor` stays in the foreground until
Cursor exits (and prints its log). Without it, `cursor` exits at once;
`--wait` returns when the first window closes, e.g. after login. Either way
nono exits too, and with it the supervisor that approves socket calls:
Cursor then shows a white window and dies.

## Rate Limit on Sockets

nono allows at most 5 socket `connect`/`bind` calls at once, refilled at
10 per second; further calls fail with "operation not permitted". The
profile sets `DBUS_SYSTEM_BUS_ADDRESS=disabled:`, so Chromium skips 5
system-bus attempts at startup.

## Access

| Access          | Paths                                                  |
|-----------------|--------------------------------------------------------|
| read + write    | the project dir, `/tmp` (no sockets), `/proc`          |
| read            | `/etc`, `/nix/store`, your git config, CPU info        |
| create sockets  | in the project dir                                     |
| connect         | Wayland display, `/run/nscd/socket` (user lookups)     |
| D-Bus           | only the portal's `OpenURI`                            |
| network         | everything                                             |

## Shortcuts

- **Wayland**: sandboxed code can type into your other windows and read the
  clipboard. The display is fixed to `wayland-1`; change it in the profile
  if yours differs.
- **Links**: sandboxed code can open any link in your browser.
- **Login in the project dir**: other sandboxes on the project (Claude Code)
  can read it.

## Does Not Work

- Opening folders outside the project.
- In the terminal: nix, `git push` over ssh, your shell config.
- GPU acceleration.
- The desktop entry and `cursor://` links start an unsandboxed Cursor.

## Test It

1. In a fresh `/tmp/cursor-test`, run `nix run ~/workbench/cursor-nono`:
   the window opens. "Log In" opens your browser.
2. In the terminal, these must fail: `ls /home/$USER/.ssh`,
   `ls /home/$USER/workbench`, `busctl --user list`.
3. `git config user.name` prints your name.

For a shell in the sandbox, use `nono run --profile cursor/cursor.profile.json
-- sh -c sh` (`sh -c` ignores the Cursor flags the profile appends).
