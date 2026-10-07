# Claude Code in a nono Sandbox

```sh
cd ~/workbench/my-project
claude-nono --dangerously-skip-permissions   # from `nix develop ~/workbench/cursor-nono`
```

`claude-nono` runs Claude Code from this flake's nixpkgs, not the `claude` on your PATH.

Linux and macOS are tested. To re-test macOS, see `../TESTING-MACOS.md`.

## Access

| Access          | Paths                                                          |
|-----------------|----------------------------------------------------------------|
| read + write    | the project dir, `/tmp` (no sockets)                           |
| read + write    | `~/.claude`, `~/.claude.json`, Claude's cache and state dirs   |
| read + write    | build caches: `~/.cargo`, `~/.rustup`, `~/.sbt`, `~/.ivy2`, `~/.npm`, `~/.cache/uv`; Linux: `~/.cache/coursier`, `~/.local/share/pnpm`, `~/.cache/pip`; macOS: `~/Library/Caches/Coursier`, `~/Library/pnpm`, `~/Library/Caches/pip` |
| read            | `/nix/store`, your git config, `/etc/passwd`, `/etc/group`     |
| unix sockets    | Linux: `/run/nscd/socket`; macOS: DNS (mDNSResponder)          |
| network         | everything                                                     |
| open in browser | login pages of claude.ai and Anthropic (Linux)                 |

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
- macOS: Claude Code keeps its login in the keychain, which nono blocks.
  If the login does not stick, create a token outside the sandbox with
  `claude setup-token` and export it as `CLAUDE_CODE_OAUTH_TOKEN`. If the
  login page does not open, copy the URL Claude prints.

## Test It

These must fail: `ls ~/.ssh`, `touch ~/.bashrc`, `busctl --user list`.
These must work: `git status`, `cargo build`, `touch /tmp/x`.
