# Claude Code in a nono Sandbox

```sh
cd ~/workbench/my-project
claude-nono --dangerously-skip-permissions   # from `nix develop ~/workbench/cursor-nono`
```

`claude` must be the plain binary, not another sandbox wrapper.

## Access

| Access          | Paths                                                          |
|-----------------|----------------------------------------------------------------|
| read + write    | the project dir, `/tmp` (no sockets)                           |
| read + write    | `~/.claude`, `~/.claude.json`, Claude's cache and state dirs   |
| read + write    | build caches: `~/.cargo`, `~/.rustup`, `~/.sbt`, `~/.ivy2`, `~/.cache/coursier`, `~/.npm`, `~/.local/share/pnpm`, `~/.cache/pip`, `~/.cache/uv` |
| read            | `/nix/store`, your git config, `/etc/passwd`, `/etc/group`, `/etc/machine-id` |
| connect         | `/run/nscd/socket` (user lookups)                              |
| network         | everything                                                     |
| open in browser | login pages of claude.ai and Anthropic                         |

## Shortcuts: the Sandbox Can Escape

- **Build caches are shared with your host.** The sandbox can replace
  `~/.cargo/bin/cargo` or a cached package; your next build outside runs
  its code. We accept this so dependencies download once.
- **`~/.claude` is shared with your host.** The sandbox can add hooks and
  MCP servers. **Never run plain `claude` outside the sandbox.** All
  projects share this config, so one session can read other transcripts.

## Does Not Work

- nix commands, `git push` over ssh, pasting images.
- A cache dir that does not exist yet: create it once on the host
  (`mkdir ~/.cache/uv`).

## Test It

These must fail: `ls ~/.ssh`, `touch ~/.bashrc`, `busctl --user list`.
These must work: `git status`, `cargo build`, `touch /tmp/x`.
