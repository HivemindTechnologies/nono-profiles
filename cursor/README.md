# Cursor in a nono Sandbox

```sh
cd ~/workbench/my-project
nix develop   # optional: gives Cursor's terminal the project's tools
nono run --profile ~/workbench/cursor-nono/cursor/cursor.profile.json -- cursor
```

`cursor.profile.json` defines the whole sandbox; there is no launcher
script. The project dir is the directory you start from (`$WORKDIR` in the
profile). Start from `~/workbench` to get one sandbox for all projects there.

Add `.cursor-nono/` to the project's `.gitignore`: it holds your Cursor login.

## Cursor's Home Lives in the Project

Inside the sandbox, `HOME` is `<project>/.cursor-nono/home` and `TMPDIR` is
`<project>/.cursor-nono/tmp`. Cursor keeps all its data under `HOME`: login,
settings, extensions, chats, `.cursor/mcp.json` and hooks. So each project
needs its own login, and your normal `~/.config/Cursor` and `~/.cursor` stay
untouched. This matters: if the sandbox could edit `~/.cursor/mcp.json`, an
unsandboxed Cursor would later run what it put there.

The home lives in the project because nono only grants paths that already
exist, and a profile cannot create directories. The project dir always
exists and is granted, so Cursor can create `.cursor-nono/` itself on first
start. (Not yet verified that Cursor creates a missing `HOME` and `TMPDIR`;
see Test It, step 1.)

The profile strips `XDG_RUNTIME_DIR`, so Cursor's single-instance socket also
lives under that `HOME`: sandboxed and unsandboxed Cursors never find each
other, and neither do Cursors of different projects.

## What Cursor Can Access

| Access                  | Paths                                                         |
|-------------------------|---------------------------------------------------------------|
| read + write            | the project dir, including `.cursor-nono/`                    |
| read + write            | `/tmp` (sockets there stay blocked)                           |
| read + write            | `/proc` (Chromium's own sandbox needs it)                     |
| read                    | `/etc`, `/nix/store` and nix profiles, your git config, CPU info |
| create sockets          | anywhere in the project dir (Cursor's IPC sockets in `TMPDIR`) |
| connect                 | `/run/nscd/socket` (user and host name lookups)               |
| connect                 | `$XDG_RUNTIME_DIR/wayland-1` (the Wayland display)            |
| network                 | everything                                                    |

Everything else is blocked, including `~/.ssh`, shell configs, other projects,
D-Bus, the nix daemon, the ssh-agent and X11.

## Environment Set by the Profile

| Variable                 | Value                              | Why |
|--------------------------|------------------------------------|-----|
| `HOME`, `TMPDIR`         | `<project>/.cursor-nono/{home,tmp}` | see above; Cursor creates its IPC sockets in `TMPDIR`, and sockets in `/tmp` are blocked |
| `WAYLAND_DISPLAY`        | `$XDG_RUNTIME_DIR/wayland-1`       | `XDG_RUNTIME_DIR` is stripped, so a relative name would not resolve; libwayland accepts an absolute path |
| `NIXOS_OZONE_WL`         | `1`                                | makes the NixOS `cursor` wrapper use Wayland |
| `GIT_CONFIG_GLOBAL`      | `~/.config/git/config`             | git looks under `HOME`, which is the project-local one |
| `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_0`, `GIT_CONFIG_VALUE_0` | `core.excludesFile=~/.config/git/ignore` | same reason, for your global gitignore |

Profile variables (`$HOME`, `$XDG_RUNTIME_DIR`) expand from your real
environment before the sandbox starts, so `~` above is your real home.

The profile also appends these arguments to `cursor`: `--ozone-platform=wayland
--disable-gpu --disable-dev-shm-usage --password-store=basic <project dir>`.

## Shortcuts We Take

- **Wayland.** Sway lets every window use the virtual keyboard and read the
  clipboard. Sandboxed code could type into your other windows, for example a
  terminal. Fixing this needs a restricted Wayland socket (`way-secure`), which
  is not packaged yet.
- **The Wayland display name is fixed to `wayland-1`.** A profile cannot read
  `WAYLAND_DISPLAY`. If your compositor uses another name, Cursor's window does
  not open; change both `wayland-1` entries in the profile.
- **The login lives in the project dir.** Any other sandbox with access to the
  project, such as Claude Code, can read it, and `git add -A` commits it
  unless `.cursor-nono/` is ignored.
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

1. `mkdir -p /tmp/cursor-test && cd /tmp/cursor-test`, then start Cursor as
   above: the window opens and `/tmp/cursor-test/.cursor-nono/` appears.
2. Log in. If no browser opens, copy the login URL by hand.
3. In the integrated terminal, each of these must fail (`~` there is the
   sandbox home, so use real paths):
   `ls /home/$USER/.ssh`, `ls /home/$USER/workbench`, `busctl --user list`.
4. `git init && git config user.name` must work and print your name.
5. Let the agent run a command in chat. This tests Cursor's own terminal sandbox.
6. If the window does not open, append `--no-sandbox` after `cursor`. That
   turns off only Chromium's internal sandbox; nono still applies.
