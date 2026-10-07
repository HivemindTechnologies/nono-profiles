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
        # Cursor does not create the dirs the profile points to.
        mkdir -p .cursor-nono/home .cursor-nono/data .cursor-nono/tmp
        # A D-Bus proxy that only opens links (via the desktop portal).
        bus=$PWD/.cursor-nono/bus
        rm -f "$bus"
        xdg-dbus-proxy "''${DBUS_SESSION_BUS_ADDRESS:?}" "$bus" --filter \
          --call='org.freedesktop.portal.Desktop=org.freedesktop.portal.OpenURI.OpenURI@/org/freedesktop/portal/desktop' \
          --call='org.freedesktop.portal.Desktop=org.freedesktop.DBus.Introspectable.Introspect@/org/freedesktop/portal/desktop' &
        trap 'kill $!' EXIT
        until [[ -S $bus ]]; do sleep 0.05; done
        set -x
        nono run --no-diagnostics --profile ${./cursor/cursor.profile.json} -- cursor "$@"
      '';

      cursorDarwin = pkgs: ''
        # Cursor does not create the dirs the profile points to.
        mkdir -p .cursor-nono/home .cursor-nono/data .cursor-nono/tmp
        # bin/cursor starts the app via `open`, which nono blocks.
        # So we run the app binary directly.
        set -x
        nono run --no-diagnostics --profile ${./cursor/cursor.profile.json} \
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
            set -x
            nono run --no-diagnostics --profile ${./claude/claude.profile.json} -- claude "$@"
          '';
        };
        default = cursor-nono;
      };
    in {
      packages = forAllSystems packagesFor;
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # Plain tools, to debug the wrappers. Alone, they run unsandboxed.
          packages = with packagesFor pkgs; [ cursor-nono claude-nono ]
            ++ [ pkgs.nono pkgs.claude-code pkgs.code-cursor ];
        };
      });
    };
}
