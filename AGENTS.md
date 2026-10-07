# nono-profiles

nono sandboxes for Cursor and Claude Code, shipped as a nix flake.

## File Structure

```
flake.nix                  wrappers cursor-nono, claude-nono,
                           cursor-nono-allow-launch-services (macOS); dev shell
README.md                  user guide: start, goal (what is blocked/allowed)
DESIGN.md                  why the flake and profiles look the way they do
<tool>/<tool>.profile.json nono profile for one tool
<tool>/README.md           user guide for that tool
<tool>/DESIGN.md           why that tool's profile/launcher look as they do
```

A tool without design notes has no `DESIGN.md`.

## Docs

- **README.md** is a short, clear guide for a human user. Tool READMEs keep
  this section order: intro, Start, Log In, (tool-specific sections),
  Access, Known Gaps, Does Not Work, Test It. Keep rationale out; link to
  `DESIGN.md` instead.
- **DESIGN.md** holds the why: each grant, each workaround, each rejected
  alternative. Every surprising line in a profile or wrapper has its reason
  here.

## Wrappers (`flake.nix`)

Keep them slim: create dirs, then `set -x` and `nono run ...`, so the user
sees the exact command. No custom flags: a variant is its own wrapper. Comments are one short,
human-readable line; longer reasons go into `DESIGN.md`.

## Testing

Run "Test It" from each tool's README after changing a profile or after
`nix flake update`.
