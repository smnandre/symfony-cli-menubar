#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_BUNDLE="$ROOT_DIR/build/SymfonyCLIMenuBar.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/SymfonyCLIMenuBar"
BUILD_APP=1
SMOKE_TEST=0

for argument in "$@"; do
    case "$argument" in
        --no-build) BUILD_APP=0 ;;
        --smoke) SMOKE_TEST=1 ;;
        *)
            printf 'Usage: %s [--no-build] [--smoke]\n' "$(basename "$0")" >&2
            exit 64
            ;;
    esac
done

pkill -f "$EXECUTABLE" 2>/dev/null || true

if [[ "$BUILD_APP" == 1 ]]; then
    "$ROOT_DIR/scripts/package.sh" release
fi

if [[ ! -x "$EXECUTABLE" ]]; then
    printf 'ERROR: Missing packaged executable: %s\n' "$EXECUTABLE" >&2
    exit 66
fi

open "$APP_BUNDLE"

PID=""
for _ in {1..20}; do
    PID=$(pgrep -f "$EXECUTABLE" | head -n 1 || true)
    if [[ -n "$PID" ]]; then
        break
    fi
    sleep 0.25
done

if [[ -z "$PID" ]]; then
    printf 'ERROR: SymfonyCLIMenuBar did not start.\n' >&2
    exit 70
fi

sleep 2
if ! kill -0 "$PID" 2>/dev/null; then
    printf 'ERROR: SymfonyCLIMenuBar exited during startup.\n' >&2
    exit 70
fi

printf 'SymfonyCLIMenuBar is running with PID %s.\n' "$PID"

if [[ "$SMOKE_TEST" == 1 ]]; then
    kill "$PID"
fi
