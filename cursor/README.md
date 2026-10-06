# Cursor in a nono Sandbox

```sh
cd ~/workbench/my-project   # per project: sees only my-project
cd ~/workbench              # broad: sees all projects
nono run --profile ~/workbench/cursor-nono/cursor/cursor.profile.json -- cursor
```

Add `.cursor-nono/` to the project's `.gitignore`. It holds your login.

## Own Home per Project

Inside the sandbox, `HOME` is `<project>/.cursor-nono/home`. Cursor keeps
login, settings, extensions, chats, `mcp.json` and hooks there. Your real
`~/.cursor` stays untouched, so the sandbox cannot plant hooks that an
unsandboxed Cursor would run. Each project needs its own login.

The home lives in the project because nono grants only paths that exist,
and a profile cannot create them.

## Access

| Access          | Paths                                                  |
|-----------------|--------------------------------------------------------|
| read + write    | the project dir, `/tmp` (no sockets), `/proc`          |
| read            | `/etc`, `/nix/store`, your git config, CPU info        |
| create sockets  | in the project dir                                     |
| connect         | Wayland display, `/run/nscd/socket` (user lookups)     |
| network         | everything                                             |

## Shortcuts

- **Wayland**: sandboxed code can type into your other windows and read the
  clipboard. The display is fixed to `wayland-1`; change it in the profile
  if yours differs.
- **Login in the project dir**: other sandboxes on the project (Claude Code)
  can read it.

## Does Not Work

- Opening folders outside the project.
- In the terminal: nix, `git push` over ssh, your shell config.
- GPU acceleration.
- The desktop entry and `cursor://` links start an unsandboxed Cursor.

## Test It

1. In `/tmp/cursor-test`, start Cursor: the window opens and `.cursor-nono/`
   appears. If not, run `mkdir -p .cursor-nono/{home,tmp}` and retry, then
   try `cursor --no-sandbox` (turns off only Chromium's own sandbox).
2. In the terminal, these must fail: `ls /home/$USER/.ssh`,
   `ls /home/$USER/workbench`, `busctl --user list`.
3. `git config user.name` prints your name.
