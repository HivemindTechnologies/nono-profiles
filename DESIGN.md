# Design Notes

Why the flake and profiles look the way they do. For usage, see
[`README.md`](README.md). Cursor-specific notes:
[`cursor/DESIGN.md`](cursor/DESIGN.md).

- Each profile is self-contained: it extends only nono's built-in `default`.
  macOS settings live in each profile's `platform_overrides.macos` section.
- Cursor needs a small launcher (`flake.nix`) so that it can open links.
- The flake pins nono, Cursor and Claude Code (`flake.lock`).
  `nix flake update` updates them; afterwards, run "Test It" in each tool's
  README.
- The wrappers use `nono run`, not `nono wrap`: only `nono run` keeps the
  supervisor process that enforces the socket rules.
