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

      cursorDarwin = pkgs: nonoFlags: ''
        # Cursor does not create the dirs the profile points to.
        mkdir -p .cursor-nono/home .cursor-nono/data .cursor-nono/tmp
        # bin/cursor starts the app via `open`, which nono blocks.
        # So we run the app binary directly.
        set -x
        nono run --no-diagnostics ${nonoFlags} --profile ${./cursor/cursor.profile.json} \
          -- ${pkgs.code-cursor}/Applications/Cursor.app/Contents/MacOS/Cursor "$@"
      '';

      mkCursor = pkgs: name: text: pkgs.writeShellApplication {
        inherit name text;
        runtimeInputs = [ pkgs.nono pkgs.code-cursor ]
          ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.xdg-dbus-proxy;
      };

      packagesFor = pkgs: rec {
        cursor-nono = mkCursor pkgs "cursor-nono"
          (if pkgs.stdenv.hostPlatform.isLinux then cursorLinux pkgs else cursorDarwin pkgs "");
        claude-nono = pkgs.writeShellApplication {
          name = "claude-nono";
          runtimeInputs = [ pkgs.nono pkgs.claude-code ];
          text = ''
            set -x
            nono run --no-diagnostics --profile ${./claude/claude.profile.json} -- claude "$@"
          '';
        };
        default = cursor-nono;
      } // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        # Opens links, so you can log in, but also lets the sandbox start any app.
        cursor-nono-allow-launch-services = mkCursor pkgs "cursor-nono-allow-launch-services"
          (cursorDarwin pkgs "--allow-launch-services");
      };
    in {
      packages = forAllSystems packagesFor;
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # All wrappers, plus the plain tools to debug them.
          # Alone, the plain tools run unsandboxed.
          packages = builtins.attrValues (removeAttrs (packagesFor pkgs) [ "default" ])
            ++ [ pkgs.nono pkgs.claude-code pkgs.code-cursor ];
        };
      });
    };
}
