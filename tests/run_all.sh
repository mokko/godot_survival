#!/usr/bin/env bash
# Run all headless tests and report a pass/fail summary.
# Usage: tests/run_all.sh [godot-command]
#   godot-command defaults to "snap run godot-4" on Linux.
set -u
cd "$(dirname "$0")/.."

GODOT="${1:-}"
if [ -z "$GODOT" ]; then
    if command -v snap >/dev/null 2>&1 && snap list godot-4 >/dev/null 2>&1; then
        GODOT="snap run godot-4"
    else
        GODOT="godot"
    fi
fi

LOCK=/tmp/survivalm-godot.lock
pass=0
fail=0
failed_tests=()

for test in tests/test_*.gd; do
    name=$(basename "$test" .gd)
    # Each test is a SceneTree script: it exits 0 on pass, non-zero on fail.
    if flock -w 30 $LOCK timeout 180 $GODOT --headless --script "res://$test" > /tmp/test_$name.log 2>&1; then
        echo "PASS $name"
        pass=$((pass + 1))
    else
        echo "FAIL $name"
        grep -E "SCRIPT ERROR|ERROR" "/tmp/test_$name.log" 2>/dev/null | head -3
        tail -5 "/tmp/test_$name.log"
        fail=$((fail + 1))
    fi
done

echo
echo "Summary: $pass passed, $fail failed, $((pass + fail)) total"
[ "$fail" -eq 0 ]
