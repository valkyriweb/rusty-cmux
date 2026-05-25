#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/rusty-build-profile.sh <profile> [--launch] [-- <reload.sh args>]

Profiles:
  dev       General Rusty cmux development build.
  browser   Browser-pane reverse-engineering build.
  tabs      Workspace/surface/tab-layout reverse-engineering build.

Examples:
  scripts/rusty-build-profile.sh dev
  scripts/rusty-build-profile.sh browser --launch
  scripts/rusty-build-profile.sh tabs -- --derived-data /tmp/rusty-cmux-tabs

Notes:
  - Wraps cmux's scripts/reload.sh with isolated app names, bundle IDs, sockets,
    debug logs, CLI shims, and DerivedData paths.
  - The built app path is printed by reload.sh as `App path:`.
EOF
}

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

profile="$1"
shift

launch_args=()
extra_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --launch)
      launch_args+=("--launch")
      shift
      ;;
    --)
      shift
      extra_args+=("$@")
      break
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
done

case "$profile" in
  dev)
    tag="rusty-cmux-dev"
    name="Rusty cmux DEV"
    bundle_id="com.valkyriweb.rustycmux.dev"
    ;;
  browser)
    tag="rusty-cmux-browser"
    name="Rusty cmux Browser"
    bundle_id="com.valkyriweb.rustycmux.browser"
    ;;
  tabs)
    tag="rusty-cmux-tabs"
    name="Rusty cmux Tabs"
    bundle_id="com.valkyriweb.rustycmux.tabs"
    ;;
  *)
    echo "error: unknown profile '$profile'" >&2
    usage >&2
    exit 2
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# Homebrew currently installs Zig 0.16.x on this machine, while cmux's helper
# build script requires Zig 0.15.2. Default to the upstream-supported skip path
# for app iteration; set CMUX_SKIP_ZIG_BUILD=0 only after installing Zig 0.15.2.
export CMUX_SKIP_ZIG_BUILD="${CMUX_SKIP_ZIG_BUILD:-1}"

exec "$repo_root/scripts/reload.sh" \
  --tag "$tag" \
  --name "$name" \
  --bundle-id "$bundle_id" \
  "${launch_args[@]}" \
  "${extra_args[@]}"
