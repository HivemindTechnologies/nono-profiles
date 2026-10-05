#!/usr/bin/env bash
# Start Cursor inside the nono sandbox defined by cursor.profile.json.
#
# Usage: launch.sh <workdir> <instance> [cursor args...]
#   <workdir>   the only project directory the sandbox can read and write
#   <instance>  name of the instance dir: ~/.local/share/cursor-nono/<instance>
#
# Each instance runs with its own HOME inside the instance dir. Cursor keeps
# everything under HOME (~/.config/Cursor, ~/.cursor with mcp.json and hooks),
# so sandboxed code can never edit files that an unsandboxed Cursor later runs.
# The profile strips XDG_RUNTIME_DIR, so Cursor's single-instance socket also
# lives in that HOME: sandboxed and unsandboxed Cursors never find each other.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <workdir> <instance> [cursor args...]" >&2
  exit 2
fi
workdir=$(realpath "$1")
instance=${XDG_DATA_HOME:-$HOME/.local/share}/cursor-nono/$2
shift 2
here=$(dirname "$(realpath "$0")")

home=$instance/home
tmp=$instance/tmp
mkdir -p "$home/.config" "$tmp"
# git in the integrated terminal needs your name and email. The profile grants
# read access to the real git config; the link makes git find it under the new HOME.
ln -sfn "$HOME/.config/git" "$home/.config/git"

# The profile strips XDG_RUNTIME_DIR, so a relative WAYLAND_DISPLAY ("wayland-1")
# would not resolve inside the sandbox. libwayland accepts an absolute path.
wayland=${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is not set; this launcher supports Wayland only}
[[ $wayland == /* ]] || wayland=${XDG_RUNTIME_DIR:?}/$wayland

# The profile grants $WORKDIR, which nono takes from the current directory.
# The instance dir and the Wayland socket differ per instance and per session,
# so they cannot live in the profile and are granted here.
# HOME and TMPDIR are set inside the sandbox (via env) because nono itself must
# still see the real HOME to resolve the profile's $HOME paths.
cd "$workdir"
exec nono run \
  --profile "$here/cursor.profile.json" \
  --allow-unix-socket-subtree-bind "$instance" \
  --allow-unix-socket "$wayland" \
  -- env HOME="$home" TMPDIR="$tmp" WAYLAND_DISPLAY="$wayland" \
  cursor \
    --ozone-platform=wayland \
    --disable-gpu \
    --disable-dev-shm-usage \
    --password-store=basic \
    "$@" \
    "$workdir"
