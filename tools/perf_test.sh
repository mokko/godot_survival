#!/usr/bin/env bash
# Frame-rate benchmark for survivalm — RUN THIS BEFORE EVERY RELEASE and keep the
# output with that release (copy it to screenshots/<date>/perf-<date>.txt).
#
# The headless test suite cannot catch a rendering regression: `--headless` has no
# renderer at all, so a change that halves the frame rate still passes 35/35.
# This is the only check that measures drawing.
#
# Usage:
#   tools/perf_test.sh              # benchmark the current build
#   tools/perf_test.sh > perf.txt   # keep the numbers with a release
#
# Needs a real display and GPU. On this machine the desktop session is Xwayland:
# from a shell without DISPLAY (e.g. an agent/cron session) export the session env
# yourself, which this script tries to do automatically:
#   DISPLAY=:0 XAUTHORITY=/run/user/$UID/.mutter-Xwaylandauth.*   (X11/Xwayland)
# Wayland also works but was measured to never present frames, which makes every
# number below meaningless — the probe reports that case as BENCHMARK INVALID.

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-snap run godot-4}"
UID_NUM="$(id -u)"

if [ -z "${DISPLAY:-}" ]; then
    if ls -1 /run/user/"$UID_NUM"/.mutter-Xwaylandauth.* >/dev/null 2>&1 \
            && [ -e /tmp/.X11-unix/X0 ]; then
        export DISPLAY=":0"
        export XAUTHORITY="$(ls -1 /run/user/"$UID_NUM"/.mutter-Xwaylandauth.* | head -1)"
        echo "# using Xwayland ($DISPLAY, auth $(basename "$XAUTHORITY"))"
    elif [ -e /run/user/"$UID_NUM"/wayland-0 ]; then
        export XDG_RUNTIME_DIR="/run/user/$UID_NUM"
        export WAYLAND_DISPLAY="wayland-0"
        echo "# WARNING: falling back to Wayland, where this machine has been"
        echo "# observed to never present frames (every sample will be INVALID)."
        echo "# Run this from the desktop session instead."
    else
        echo "# ERROR: no display found. Run this from the graphical session." >&2
        exit 2
    fi
fi

echo "# survivor benchmark  date=$(date -Is)  host=$(hostname)  godot=$GODOT"
# shellcheck disable=SC2086
timeout 900 $GODOT --audio-driver Dummy --script res://tools/perf_probe.gd 2>&1 \
    | grep --line-buffered -E "^(BENCH|RESULT|#|ERROR: .*(script|Parse))"
status="${PIPESTATUS[0]}"
if [ "$status" = "124" ]; then
    echo "# ERROR: benchmark timed out — is another Godot instance holding the GPU?" >&2
    exit 124
fi
exit "$status"
