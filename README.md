# cursor-nono

Run the Cursor IDE inside a [nono](https://nono.sh) sandbox. Self-contained: the profile
extends only nono's built-in `default` and blocks host unix sockets such as D-Bus.

The two variants share one profile and one launcher:

| Command                   | Granted directory     | Cursor data dir                                     |
|---------------------------|-----------------------|-----------------------------------------------------|
| `broad-root/cursor`       | `~/workbench`         | `~/.local/share/cursor-nono/broad-root`             |
| `per-project/cursor [dir]`| `dir` (default `.`)   | `~/.local/share/cursor-nono/per-project/<path-slug>`|

Each data dir needs its own Cursor login. Your normal `~/.config/Cursor` is never touched.

## Files

- `cursor.profile.json`: the nono profile (extends built-in `default`).
- `launch.sh <workdir> <state-name>`: scrubs the environment and runs Cursor under `nono run`.
- `broad-root/cursor`, `per-project/cursor`: thin wrappers around `launch.sh`.

## Grants and Why

| Grant                                   | Why                                                        |
|-----------------------------------------|------------------------------------------------------------|
| workdir r+w (launcher `--allow`)        | the project being edited                                   |
| state dir r+w + socket bind (launcher)  | Cursor data, extensions, TMPDIR, single-instance socket    |
| Wayland socket connect (launcher)       | display                                                    |
| `~/.cursor` r+w                         | Cursor hardcodes it (MCP config, hooks, chats, CLI)        |
| `/proc` r+w                             | Chromium's own sandbox writes `/proc/self/uid_map`         |
| `~/.cache/fontconfig` r+w               | font cache                                                 |
| `/etc`, `~/.config/gtk-3.0`, CPU info r | fonts, TLS certs, GTK theme, Chromium CPU detection        |
| groups `nix_runtime`, `git_config`      | run nix-store binaries; git in the integrated terminal     |

The profile strips `DBUS_SESSION_BUS_ADDRESS`, `DISPLAY` and `XDG_RUNTIME_DIR` and sets
`NIXOS_OZONE_WL=1`.

## What the Sandbox Blocks

- Files outside the grants above, including your shell configs and ssh keys.
- Pathname unix sockets (D-Bus session bus, `systemd-run --user`, portals), except
  Wayland and Cursor's own sockets. This also blocks ssh-agent and nix-daemon, so
  `git push` over ssh and `nix shell` fail in the integrated terminal.
- X11: `DISPLAY` is stripped, Cursor runs as a native Wayland client.

## Known Gaps

- Wayland: sway gives every client virtual-keyboard and data-control. Sandboxed code can
  inject keystrokes into other windows or read the clipboard. A fix would be a
  wp-security-context-v1 socket (e.g. `way-secure`).
- `~/.cursor` (MCP config, hooks, chats) is shared by all instances.
- "Open Folder" outside the granted directory fails with EACCES.
- The desktop entry and the `cursor://` handler still start an unsandboxed Cursor.
- The network is unrestricted.

## Host Test

Run each step and note the result:

1. `./per-project/cursor /tmp/cursor-test`: the window opens.
2. Log in. Copy the login URL by hand if no browser opens.
3. In the integrated terminal run:
   - `ls ~/.ssh/id_ed25519`: denied.
   - `ls ~/workbench`: denied (per-project only).
   - `busctl --user list`: fails (no D-Bus).
   - `systemd-run --user true`: fails.
   - `git -C /tmp/cursor-test init`: works.
4. Open the agent chat and let it run a command (tests Cursor's own terminal sandbox).
5. If the window does not open, retry with `--no-sandbox` as the last argument. That
   disables only Chromium's internal sandbox; nono still applies.
