# Claude Code in a nono Sandbox

```sh
cd ~/workbench/my-project
nix develop -c ~/workbench/cursor-nono/claude-code/claude-nono --dangerously-skip-permissions
```

`claude-nono` runs `claude` from your PATH. If that `claude` is itself a
sandbox wrapper, set `CLAUDE_BIN` to the plain Claude Code binary.

## What Claude Can Access

| Access                         | Paths                                                        |
|--------------------------------|--------------------------------------------------------------|
| read + write                   | the current directory                                        |
| read + write                   | `~/.claude`, `~/.claude.json`, Claude's cache and lock dirs  |
| read + write (build caches)    | `~/.cargo`, `~/.rustup`, `~/.sbt`, `~/.ivy2`, `~/.cache/coursier`, `~/.npm`, `~/.local/share/pnpm`, `~/.cache/pip`, `~/.cache/uv` |
| read + write (temp)            | `~/.cache/claude-nono/tmp` (set as `TMPDIR`)                 |
| read                           | `/nix/store` and nix profiles, your git config, `/etc/passwd`, `/etc/group`, `/etc/machine-id` |
| connect                        | `/run/nscd/socket` (user and host name lookups)              |
| network                        | everything                                                   |
| opens in your browser          | login pages on claude.ai, claude.com, platform.claude.com, console.anthropic.com |

Everything else is blocked, including `~/.ssh`, shell configs, other projects,
`/tmp`, D-Bus, the nix daemon, the ssh-agent and the Wayland display.

## Risks We Accept

The first two risks let sandboxed code run code outside the sandbox.

- **Build caches are shared with your host.** The sandbox can write
  everything in them, including programs your host runs. `~/.cargo/bin`
  holds `cargo` and `rustc` and is usually on your PATH: if the sandbox
  replaces them, your next `cargo` outside the sandbox runs its code. The
  same holds for pnpm's global bin dir (`~/.local/share/pnpm`), sbt's global
  plugins (`~/.sbt`) and any poisoned package in the caches. We accept this
  so that toolchains and dependencies download once.
- **`~/.claude` and `~/.claude.json` are shared with your host.** The
  sandbox can add hooks (`~/.claude/settings.json`) and MCP servers
  (`~/.claude.json`). **Never run plain `claude` outside the sandbox**: it
  would run them unsandboxed. All projects also share this config, so one
  session can read the transcripts of other projects.
- **The temp dir is shared by all projects.** Every session uses
  `~/.cache/claude-nono/tmp`.
- **Open network.** See the top-level README.

## What Does Not Work

- `nix build`, `nix develop` and `nix shell` inside the session.
- `git push` over ssh, because neither `~/.ssh` nor the ssh-agent is reachable.
- Pasting images into Claude, because the Wayland clipboard is blocked.
- A brand-new cache dir, for example `~/.cache/uv` before you ever ran uv.
  Create it once on the host (`mkdir ~/.cache/uv`); missing paths are skipped.

## Test It

Inside a `claude-nono` session, ask Claude to run these. Each must fail:

```sh
ls ~/.ssh
touch ~/.bashrc
touch /tmp/x
busctl --user list
nix store info
```

`git status` and `cargo build` in the project must work.
