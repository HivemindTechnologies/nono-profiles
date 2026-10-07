{
  description = "nono sandboxes for Cursor and Claude Code";

  inputs.nixpkgs.url = "nixpkgs";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
        # Cursor and Claude Code are unfree.
        config.allowUnfree = true;
      }));

      cursorLinux = pkgs: ''
        # nono cannot open links from a sandbox that filters unix sockets,
        # so we expose a D-Bus proxy that allows only the portal's OpenURI call.
        # gdbus (used by xdg-open) also needs Introspect to learn the argument types.
        # The socket lives in the project dir, where the profile allows sockets.
        bus=$PWD/.cursor-nono/bus
        # The profile points HOME, the data dir and TMPDIR into .cursor-nono.
        # Cursor does not create TMPDIR, so we create all three.
        mkdir -p "$PWD/.cursor-nono/home" "$PWD/.cursor-nono/data" "$PWD/.cursor-nono/tmp"
        rm -f "$bus"
        xdg-dbus-proxy "''${DBUS_SESSION_BUS_ADDRESS:?}" "$bus" --filter \
          --call='org.freedesktop.portal.Desktop=org.freedesktop.portal.OpenURI.OpenURI@/org/freedesktop/portal/desktop' \
          --call='org.freedesktop.portal.Desktop=org.freedesktop.DBus.Introspectable.Introspect@/org/freedesktop/portal/desktop' &
        trap 'kill $!' EXIT
        until [[ -S $bus ]]; do sleep 0.05; done
        nono run --no-diagnostics --profile ${./cursor/cursor.profile.json} -- cursor "$@"
      '';

      cursorDarwin = pkgs: ''
        # The profile points HOME, the data dir and TMPDIR into .cursor-nono.
        # Cursor does not create TMPDIR, so we create all three.
        mkdir -p "$PWD/.cursor-nono/home" "$PWD/.cursor-nono/data" "$PWD/.cursor-nono/tmp"
        # macOS has no narrow way to open links: --login lets the sandbox use
        # LaunchServices, which can also start any app outside the sandbox.
        # Use it only to log in.
        extra=()
        if [[ ''${1-} == --login ]]; then shift; extra=(--allow-launch-services); fi
        # We run the app binary itself: bin/cursor would start Cursor through
        # `open` (LaunchServices), which nono blocks, or which, with --login,
        # starts Cursor outside the sandbox.
        nono run --no-diagnostics "''${extra[@]}" --profile ${./cursor/cursor.profile.json} \
          -- ${pkgs.code-cursor}/Applications/Cursor.app/Contents/MacOS/Cursor "$@"
      '';

      packagesFor = pkgs: rec {
        cursor-nono = pkgs.writeShellApplication {
          name = "cursor-nono";
          runtimeInputs = [ pkgs.nono pkgs.code-cursor ]
            ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.xdg-dbus-proxy;
          text = if pkgs.stdenv.hostPlatform.isLinux then cursorLinux pkgs else cursorDarwin pkgs;
        };
        claude-nono = pkgs.writeShellApplication {
          name = "claude-nono";
          runtimeInputs = [ pkgs.nono pkgs.claude-code ];
          text = ''
            nono run --no-diagnostics --profile ${./claude/claude.profile.json} -- claude "$@"
          '';
        };
        default = cursor-nono;
      };
    in {
      packages = forAllSystems packagesFor;
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # The plain tools are here to show and debug what the wrappers do,
          # e.g. `nono run --profile <profile> -- claude`. Typing `claude` or
          # `cursor` alone starts them unsandboxed.
          packages = with packagesFor pkgs; [ cursor-nono claude-nono ]
            ++ [ pkgs.nono pkgs.claude-code pkgs.code-cursor ];
        };
      });
    };
}
