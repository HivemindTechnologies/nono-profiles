# Cursor in a nono Sandbox

```sh
cursor/per-project/cursor-nono ~/workbench/my-project   # one sandbox per project
cursor/broad-root/cursor-nono                           # one sandbox for all of ~/workbench
```

Both start Cursor through `launch.sh`, which uses `cursor` from your PATH.

## Instances

Every sandbox is an *instance* with its own home dir:

| Command                    | Project dir         | Instance dir                                          |
|----------------------------|---------------------|-------------------------------------------------------|
| `per-project/cursor-nono`  | `dir` (default `.`) | `~/.local/share/cursor-nono/per-project/<escaped path>` |
| `broad-root/cursor-nono`   | `~/workbench`       | `~/.local/share/cursor-nono/broad-root`               |

Inside the sandbox, `HOME` points to `<instance>/home`. Cursor keeps all its
data there: login, settings, extensions, chats, `.cursor/mcp.json` and hooks.
So each instance needs its own login, and your normal `~/.config/Cursor` and
`~/.cursor` stay untouched. This matters: if the sandbox could edit
`~/.cursor/mcp.json`, an unsandboxed Cursor would later run what it put there.

## What Cursor Can Access

| Access                  | Paths                                                         |
|-------------------------|---------------------------------------------------------------|
| read + write            | the project dir                                               |
| read + write            | the instance dir (Cursor data, `TMPDIR`, its own sockets)     |
| read + write            | `/tmp` (sockets there stay blocked)                           |
| read + write            | `/proc` (Chromium's own sandbox needs it)                     |
| read                    | `/etc`, `/nix/store` and nix profiles, your git config, CPU info |
| connect                 | `/run/nscd/socket` (user and host name lookups)               |
| connect                 | the Wayland display                                           |
| network                 | everything                                                    |

Everything else is blocked, including `~/.ssh`, shell configs, other projects,
D-Bus, the nix daemon, the ssh-agent and X11.

`TMPDIR` points into the instance dir because Cursor creates its IPC sockets
there, and the sandbox may not create sockets in `/tmp`.

## Shortcuts We Take

- **Wayland.** Sway lets every window use the virtual keyboard and read the
  clipboard. Sandboxed code could type into your other windows, for example a
  terminal. Fixing this needs a restricted Wayland socket (`way-secure`), which
  is not packaged yet.
- **All of `/etc` is readable.** It is mostly links into `/nix/store`, and
  secret files there are readable by root only. Narrowing it risks breaking
  the GUI for little gain.
- **Open network, environment variables and `/tmp`.** See the top-level
  README.

## What Does Not Work

- "Open Folder" outside the project dir fails with "permission denied".
- The desktop entry and `cursor://` links still start an unsandboxed Cursor.
- In the integrated terminal: nix commands, `git push` over ssh, and your
  shell config (the shell starts bare).
- GPU acceleration is off (`--disable-gpu`).

## Test It

1. `mkdir -p /tmp/cursor-test && cursor/per-project/cursor-nono /tmp/cursor-test`:
   the window opens.
2. Log in. If no browser opens, copy the login URL by hand.
3. In the integrated terminal, each of these must fail:
   `ls ~/.ssh`, `ls ~/workbench`, `busctl --user list`.
4. `git -C /tmp/cursor-test init` must work.
5. Let the agent run a command in chat. This tests Cursor's own terminal sandbox.
6. If the window does not open, append `--no-sandbox`. That turns off only
   Chromium's internal sandbox; nono still applies.
