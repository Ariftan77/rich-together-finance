#!/bin/bash
# Opens the iOS Simulator and runs Rich Together on it (debug, hot reload enabled).
# Double-click in Finder, or run: ./run_ios_sim.command
# Pick a different device:   SIM_NAME="iPhone 17e" ./run_ios_sim.command
set -euo pipefail

cd "$(dirname "$0")"

FLUTTER="$(command -v flutter || true)"
[ -z "$FLUTTER" ] && FLUTTER="$HOME/Documents/Development/flutter/bin/flutter"
if [ ! -x "$FLUTTER" ]; then
  echo "❌ flutter not found on PATH or at $FLUTTER"
  read -r -p "Press Enter to close..."
  exit 1
fi

SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"

# Resolve the simulator UDID: prefer one already booted, then SIM_NAME, then any iPhone.
find_udid() {
  xcrun simctl list devices available | grep -E "$1" | head -1 | grep -oE '[0-9A-F-]{36}' || true
}
UDID="$(find_udid 'iPhone.*\(Booted\)')"
[ -z "$UDID" ] && UDID="$(find_udid "^ +${SIM_NAME} \(")"
[ -z "$UDID" ] && UDID="$(find_udid '^ +iPhone')"
if [ -z "$UDID" ]; then
  echo "❌ No available iPhone simulator. Install one in Xcode → Settings → Platforms."
  read -r -p "Press Enter to close..."
  exit 1
fi

echo "📱 Simulator: $(xcrun simctl list devices | grep "$UDID" | sed -E 's/^ +//')"
open -a Simulator
xcrun simctl boot "$UDID" 2>/dev/null || true   # already booted is fine
xcrun simctl bootstatus "$UDID" -b >/dev/null

echo "📦 flutter pub get..."
"$FLUTTER" pub get

echo "🚀 Running on simulator (r = hot reload, R = hot restart, q = quit)"
"$FLUTTER" run -d "$UDID"
