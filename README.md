# nono Sandboxes for Cursor and Claude Code

Run AI coding tools in a [nono](https://nono.sh) sandbox, so that code they
write or run cannot touch the rest of your machine. Linux and macOS (Apple
Silicon) are tested.

## Start

Start from the project dir. The sandbox can write only that dir.

```sh
nix develop ~/workbench/cursor-nono
cd ~/workbench/my-project
cursor-nono
claude-nono --dangerously-skip-permissions
```

Each wrapper runs `nono run --profile <profile> -- <tool>` and prints that
command first. Details per tool: [`cursor/README.md`](cursor/README.md),
[`claude/README.md`](claude/README.md).

macOS: Cursor needs one extra step to log in, see "Log In" in
[`cursor/README.md`](cursor/README.md#log-in).

The dev shell also has plain `nono`, `claude` and `cursor`, to debug the
wrappers. **Alone, `claude` and `cursor` run unsandboxed.**

Nix does not work inside the sandbox. Start the tool from a dev shell
(`nix develop -c ...`) to give it the project's tools.

## Goal: Secure, but Pragmatic

Nothing inside the sandbox may run code outside of it. The Claude Code
sandbox breaks this on purpose; see "Known Gaps" in its README.

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

Why things are built this way: [`DESIGN.md`](DESIGN.md).
