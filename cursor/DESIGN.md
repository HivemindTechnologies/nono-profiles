# Cursor Sandbox: Design Notes

Why the Cursor profile and launcher look the way they do. For usage, see
[`README.md`](README.md).

## Own Dirs

The launcher (`flake.nix`) creates `home`, `data` and `tmp` in
`.cursor-nono`. Cursor does not create `TMPDIR` itself: on macOS, it did not
start without it.

## Opening Links on Linux

The launcher runs `xdg-dbus-proxy` at `.cursor-nono/bus`. It passes on only
the desktop portal's `OpenURI` call (plus read-only `Introspect`), which
opens the link in your default browser. Everything else on D-Bus stays
blocked. macOS has no such narrow way.

nono's own `open_urls` does not work for Cursor: on Linux nono deadlocks
when its link helper runs under `af_unix_mediation`, and on macOS Electron
opens links through LaunchServices, not through nono's helper.

## Why `--verbose`

The profile passes `--verbose`, so `cursor` stays in the foreground until
Cursor exits (and prints its log). Without it, `cursor` exits at once;
`--wait` returns when the first window closes, e.g. after login. Either way
nono exits too, and with it the supervisor that approves socket calls:
Cursor then shows a white window and dies.

## The App Binary on macOS

The launcher skips `cursor` and runs `Cursor.app/Contents/MacOS/Cursor`
directly: `cursor` starts the app through `open` (LaunchServices), which
nono blocks (error -54) or, with `--allow-launch-services`, which starts
Cursor outside the sandbox.

## macOS Seatbelt Rules

The profile adds raw Seatbelt rules in `platform_overrides.macos`:

- `deny network-outbound (regex "^/")` blocks all unix sockets by path.
  The allows after it reopen DNS (mDNSResponder) and Cursor's own sockets
  in `.cursor-nono/`.
- Without `user-preference-read/write`, `file-issue-extension`,
  `RootDomainUserClient`, `mach-register` and `mach-lookup`, Cursor died
  right after start. `mach-lookup` is broad: it allows any mach service.
- Without `IOSurfaceRootUserClient`, the window stayed blank ("Failed to
  allocate IOSurface"). `IOHIDParamUserClient` came with the same fix; its
  own need was not tested separately.
- `--no-sandbox`: Chromium's own sandbox cannot start inside nono's.

## Rate Limit on Sockets (Linux)

nono allows at most 5 socket `connect`/`bind` calls at once, refilled at 10
per second; further calls fail with "operation not permitted". The profile
sets `DBUS_SYSTEM_BUS_ADDRESS=disabled:`, so Chromium skips 5 system-bus
attempts at startup.

## Debugging

For a shell in the sandbox, use
`nono run --profile cursor/cursor.profile.json -- sh -c sh` (`sh -c` ignores
the Cursor flags the profile appends).
