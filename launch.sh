#!/usr/bin/env bash
# Start Cursor inside the nono sandbox defined by cursor.profile.json.
#
# Usage: launch.sh <workdir> <state-name> [cursor args...]
#   <workdir>     the only project directory the sandbox can read and write
#   <state-name>  selects the Cursor data dir: ~/.local/share/cursor-nono/<state-name>
#
# Every sandboxed instance gets its own Cursor data dir instead of ~/.config/Cursor.
# The profile strips XDG_RUNTIME_DIR, so Cursor puts its single-instance socket
# inside that data dir. A sandboxed and an unsandboxed Cursor therefore never find
# each other's socket and never hand folders to one another.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <workdir> <state-name> [cursor args...]" >&2
  exit 2
fi
workdir=$(realpath "$1")
state=${XDG_DATA_HOME:-$HOME/.local/share}/cursor-nono/$2
shift 2
here=$(dirname "$(realpath "$0")")

mkdir -p "$state/data" "$state/extensions" "$state/tmp"

# The profile strips XDG_RUNTIME_DIR, so a relative WAYLAND_DISPLAY ("wayland-1")
# would not resolve inside the sandbox. libwayland accepts an absolute path.
wayland=${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is not set; this launcher supports Wayland only}
[[ $wayland == /* ]] || wayland=${XDG_RUNTIME_DIR:?}/$wayland

# Cursor creates its IPC sockets in TMPDIR. A private TMPDIR inside the state dir
# avoids granting socket bind in /tmp, which would also allow connecting to every
# other socket in /tmp (e.g. /tmp/.X11-unix).
cd "$workdir"
exec env WAYLAND_DISPLAY="$wayland" TMPDIR="$state/tmp" \
  nono run \
    --profile "$here/cursor.profile.json" \
    --workdir "$workdir" \
    --name "cursor-$(basename "$workdir")" \
    --allow-unix-socket-subtree-bind "$state" \
    --allow-unix-socket "$wayland" \
    -- cursor \
      --user-data-dir "$state/data" \
      --extensions-dir "$state/extensions" \
      --ozone-platform=wayland \
      --disable-gpu \
      --disable-dev-shm-usage \
      --password-store=basic \
      "$@" \
      "$workdir"
