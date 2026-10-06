{
  description = "nono sandboxes for Cursor and Claude Code";

  inputs.nixpkgs.url = "nixpkgs";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      # nono 0.68 cannot open links from a sandbox that filters unix sockets,
      # so we expose a D-Bus proxy that allows only the portal's OpenURI call.
      # gdbus (used by xdg-open) also needs Introspect to learn the argument types.
      # The socket lives in the project dir, where the profile allows sockets.
      cursor-nono = pkgs.writeShellApplication {
        name = "cursor-nono";
        runtimeInputs = [ pkgs.xdg-dbus-proxy ];
        text = ''
          bus=$PWD/.cursor-nono/bus
          mkdir -p "$PWD/.cursor-nono/home"
          rm -f "$bus"
          xdg-dbus-proxy "''${DBUS_SESSION_BUS_ADDRESS:?}" "$bus" --filter \
            --call='org.freedesktop.portal.Desktop=org.freedesktop.portal.OpenURI.OpenURI@/org/freedesktop/portal/desktop' \
            --call='org.freedesktop.portal.Desktop=org.freedesktop.DBus.Introspectable.Introspect@/org/freedesktop/portal/desktop' &
          trap 'kill $!' EXIT
          until [[ -S $bus ]]; do sleep 0.05; done
          nono run --no-diagnostics --profile ${./cursor/cursor.profile.json} -- cursor "$@"
        '';
      };
      claude-nono = pkgs.writeShellApplication {
        name = "claude-nono";
        text = ''
          nono run --no-diagnostics --profile ${./claude-code/claude-code.profile.json} -- claude "$@"
        '';
      };
    in {
      packages.x86_64-linux = { inherit cursor-nono claude-nono; default = cursor-nono; };
      devShells.x86_64-linux.default = pkgs.mkShell { packages = [ cursor-nono claude-nono ]; };
    };
}
