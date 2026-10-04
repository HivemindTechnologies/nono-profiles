# Claude Code in a nono Sandbox

```sh
cd ~/workbench/my-project
nix develop -c ~/workbench/cursor-nono/claude-code/claude-nono --dangerously-skip-permissions
```

## What Claude Can Access

| Access                         | Paths                                                        |
|--------------------------------|--------------------------------------------------------------|
| read + write                   | the current directory                                        |
| read + write                   | `~/.claude`, `~/.claude.json`, Claude's cache and lock dirs  |
| read + write (build caches)    | `~/.cargo`, `~/.rustup`, `~/.sbt`, `~/.ivy2`, `~/.cache/coursier`, `~/.npm`, `~/.local/share/pnpm`, `~/.cache/pip`, `~/.cache/uv` |
| read + write (temp)            | `~/.cache/claude-nono/tmp` (set as `TMPDIR`)                 |
| read                           | `/nix/store` and nix profiles, your git config, `/etc/passwd`, `/etc/group` |
| network                        | everything                                                   |
| opens in your browser          | login pages on claude.ai, claude.com, platform.claude.com, console.anthropic.com |

Everything else is blocked, including `~/.ssh`, shell configs, other projects,
`/tmp`, D-Bus, the nix daemon, the ssh-agent and the Wayland display.

## Risks We Accept

- **Build caches are shared with your host.** A malicious dependency that
  Claude downloads lands in, say, `~/.cargo/registry`. Your next build outside
  the sandbox runs it. We accept this so that dependencies download once.
- **`~/.claude` is shared by all projects.** One session can add hooks or
  skills that later sessions run (still sandboxed), and it can read the
  transcripts of other projects.
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
