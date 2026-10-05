# Claude Code in a nono Sandbox

```sh
cd ~/workbench/my-project
nix develop   # optional: gives Claude the project's tools
nono run --profile ~/workbench/cursor-nono/claude-code/claude-code.profile.json \
  -- claude --dangerously-skip-permissions
```

`claude-code.profile.json` defines the whole sandbox; there is no launcher
script. The project dir is the directory you start from (`$WORKDIR` in the
profile). `claude` must be the plain Claude Code binary, not another sandbox
wrapper.

## What Claude Can Access

| Access                         | Paths                                                        |
|--------------------------------|--------------------------------------------------------------|
| read + write                   | the current directory                                        |
| read + write                   | `~/.claude`, `~/.claude.json`, Claude's cache and lock dirs  |
| read + write (build caches)    | `~/.cargo`, `~/.rustup`, `~/.sbt`, `~/.ivy2`, `~/.cache/coursier`, `~/.npm`, `~/.local/share/pnpm`, `~/.cache/pip`, `~/.cache/uv` |
| read + write                   | `/tmp` (sockets there stay blocked)                          |
| read                           | `/nix/store` and nix profiles, your git config, `/etc/passwd`, `/etc/group`, `/etc/machine-id` |
| connect                        | `/run/nscd/socket` (user and host name lookups)              |
| network                        | everything                                                   |
| opens in your browser          | login pages on claude.ai, claude.com, platform.claude.com, console.anthropic.com |

Everything else is blocked, including `~/.ssh`, shell configs, other projects,
D-Bus, the nix daemon, the ssh-agent and the Wayland display.

## Shortcuts We Take

The first two shortcuts let sandboxed code run code outside the sandbox.

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
- **Open network, environment variables and `/tmp`.** See the top-level
  README.

## What Does Not Work

- `nix build`, `nix develop` and `nix shell` inside the session.
- `git push` over ssh, because neither `~/.ssh` nor the ssh-agent is reachable.
- Pasting images into Claude, because the Wayland clipboard is blocked.
- A brand-new cache dir, for example `~/.cache/uv` before you ever ran uv.
  Create it once on the host (`mkdir ~/.cache/uv`); missing paths are skipped.
- Tools that create unix sockets in `/tmp`, because all sockets there are
  blocked.

## Test It

Inside a sandboxed session, ask Claude to run these. Each must fail:

```sh
ls ~/.ssh
touch ~/.bashrc
busctl --user list
nix store info
```

`git status`, `cargo build` and `touch /tmp/x` must work.
