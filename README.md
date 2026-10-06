# nono Sandboxes for Cursor and Claude Code

Run AI coding tools in a [nono](https://nono.sh) sandbox, so that code they
write or run cannot touch the rest of your machine.

Start from the project dir. The sandbox can write only that dir.

```sh
nix develop ~/workbench/cursor-nono   # provides cursor-nono and claude-nono
cd ~/workbench/my-project
cursor-nono
claude-nono --dangerously-skip-permissions
```

Each command is a thin wrapper around `nono run --profile <profile> -- <tool>`.

Each profile is self-contained: it extends only nono's built-in `default`.
Cursor needs a small launcher (`flake.nix`) so that it can open links.

## Goal: Secure, but Pragmatic

Nothing inside the sandbox may run code outside of it. The Claude Code
sandbox breaks this on purpose; see its README.

Both sandboxes block:

- **Files outside the project**, apart from a short list per tool.
- **Host unix sockets**, including all sockets in `/tmp`. D-Bus can start
  programs outside the sandbox, the nix daemon is "essentially equivalent to
  root", the ssh-agent holds your keys, and tmux can type into your terminals.

Both sandboxes allow, to keep daily work smooth:

- **Open network**, including localhost.
- **Your environment variables**, except a short deny list. A token like
  `GITHUB_TOKEN` in your shell is visible inside.
- **Shared `/tmp`** (without sockets). Sandbox and host can read and change
  each other's temp files.

Nix does not work inside. Start the tool from a dev shell
(`nix develop -c ...`) to give it the project's tools.

Use `nono run`, not `nono wrap`: only `nono run` keeps the supervisor
process that enforces the socket rules.
