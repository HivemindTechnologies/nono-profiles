# nono Sandboxes for Cursor and Claude Code

Run AI coding tools inside a [nono](https://nono.sh) sandbox, so that code they
write or run cannot touch the rest of your machine.

| Folder         | Tool                     | Start in the project dir with                                   |
|----------------|--------------------------|-----------------------------------------------------------------|
| `cursor/`      | Cursor IDE (GUI)         | `nono run --profile cursor/cursor.profile.json -- cursor`       |
| `claude-code/` | Claude Code (terminal)   | `nono run --profile claude-code/claude-code.profile.json -- claude` |

Each folder is self-contained: its profile extends only nono's built-in
`default` profile, needs nothing from `~/.config/nono`, and needs no launcher
script.

## Secure, but Pragmatic

The goal is: **nothing inside the sandbox can run code outside of it.**
Beyond that, we take a few shortcuts so that daily work stays smooth. This
README lists the shortcuts both sandboxes share; each folder's README lists
its own. The Claude Code sandbox breaks the
goal on purpose in two places (shared build caches and `~/.claude`); read its
README before you use it.

Both sandboxes block:

- **Files outside the project**, apart from a short list per tool. Your ssh
  keys, shell configs and other projects are not visible.
- **Host unix sockets.** The D-Bus session bus would let sandboxed code start
  programs outside the sandbox (`systemd-run --user`). The nix daemon trusts
  your user, which nix itself calls "essentially equivalent to root". The
  ssh-agent would let sandboxed code use your ssh keys. This includes all
  sockets in `/tmp`, such as tmux and X11: tmux would let sandboxed code type
  commands into your terminals.

Shortcuts in both sandboxes:

- **Open network.** Sandboxed code can send your project anywhere and can
  reach services on localhost.
- **Environment variables pass through.** Only the variables in a profile's
  `deny_vars` are removed. A token in your shell or dev shell, such as
  `GITHUB_TOKEN`, is visible inside.
- **`/tmp` is shared with your host.** Sandboxed code can read and change
  the temp files of your host programs, and the other way round. Only
  sockets in `/tmp` stay blocked. nono itself writes session files there
  (`/tmp/.nono-*.json`); we have not checked what changing them could do.
- **Nix is not available inside.** Start the tool from a dev shell instead
  (`nix develop -c ...`), so it inherits the tools it needs.

## Why `nono run`

Both tools start with `nono run`, which keeps a small supervisor process next to
the tool. Only that supervisor enforces the socket rules above. `nono wrap`
has no supervisor, so it refuses these profiles (tested with nono 0.68).
