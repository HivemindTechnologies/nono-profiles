# Claude Code in a nono Sandbox

Claude Code runs in a nono sandbox that can write the dir you start it in,
plus Claude's own config and your build caches.

## Start

```sh
nix develop ~/workbench/cursor-nono
cd ~/workbench/my-project
claude-nono --dangerously-skip-permissions
```

`claude-nono` runs Claude Code from this flake's nixpkgs, not the `claude`
on your PATH. It prints the `nono run` command it executes.

## Log In

- **Linux**: the login page opens in your browser.
- **macOS**: if the login page does not open, copy the URL Claude prints.
  Claude Code keeps its login in the keychain, which nono blocks. If the
  login does not stick, create a token outside the sandbox with
  `claude setup-token` and export it as `CLAUDE_CODE_OAUTH_TOKEN`.

## Access

| Access          | Paths                                                          |
|-----------------|----------------------------------------------------------------|
| read + write    | the project dir, `/tmp` (no sockets)                           |
| read + write    | `~/.claude`, `~/.claude.json`, Claude's cache and state dirs   |
| read + write    | build caches: `~/.cargo`, `~/.rustup`, `~/.sbt`, `~/.ivy2`, `~/.npm`, `~/.cache/uv` |
| read + write    | Linux: `~/.cache/coursier`, `~/.local/share/pnpm`, `~/.cache/pip` |
| read + write    | macOS: `~/Library/Caches/Coursier`, `~/Library/pnpm`, `~/Library/Caches/pip` |
| read            | `/nix/store`, your git config, `/etc/passwd`, `/etc/group`     |
| unix sockets    | Linux: `/run/nscd/socket`; macOS: DNS (mDNSResponder)          |
| network         | everything                                                     |
| open in browser | Linux: login pages of claude.ai and Anthropic                  |

## Known Gaps

Both gaps let the sandbox run code outside of it:

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

1. These must fail: `ls ~/.ssh`, `touch ~/.bashrc`, `busctl --user list`.
2. These must work: `git status`, `cargo build`, `touch /tmp/x`.
3. macOS: these must fail as well:

   ```sh
   open -a Calculator
   launchctl submit -l nono-escape -- /usr/bin/touch /Users/$USER/nono-escaped
   osascript -e "tell application \"Terminal\" to do script \"touch /Users/$USER/nono-escaped\""
   for s in $(find /private/tmp -type s 2>/dev/null); do nc -U "$s" </dev/null && echo "REACHED $s"; done
   ```

   Then, outside the sandbox: `ls ~/nono-escaped` must report "No such
   file"; clean up with `launchctl remove nono-escape`.
