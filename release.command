#!/bin/bash
# Release build for Rich Together (iOS IPA and/or Android App Bundle).
#  1. Asks whether to bump the version; if yes, updates pubspec.yaml AND the
#     Runner target in ios/Runner.xcodeproj (MARKETING_VERSION / CURRENT_PROJECT_VERSION).
#  2. Runs flutter analyze (fails on errors only) and flutter test.
#  3. Builds the release artifacts.
# Double-click in Finder, or run: ./release.command
set -euo pipefail

cd "$(dirname "$0")"

pause_exit() { read -r -p "Press Enter to close..."; exit "${1:-0}"; }
trap 'echo; echo "❌ Release aborted (line $LINENO)."; pause_exit 1' ERR

FLUTTER="$(command -v flutter || true)"
[ -z "$FLUTTER" ] && FLUTTER="$HOME/Documents/Development/flutter/bin/flutter"
[ -x "$FLUTTER" ] || { echo "❌ flutter not found"; pause_exit 1; }

PUBSPEC="pubspec.yaml"
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
APP_BUNDLE_ID="com.axiomtechdev.richtogether"

# ---------- Current version ----------
CURRENT="$(grep -E '^version: ' "$PUBSPEC" | sed -E 's/^version: *//')"
if ! [[ "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  echo "❌ Unexpected version format in pubspec.yaml: '$CURRENT' (expected x.y.z+n)"
  pause_exit 1
fi
MAJ=${BASH_REMATCH[1]}; MIN=${BASH_REMATCH[2]}; PAT=${BASH_REMATCH[3]}; BUILD=${BASH_REMATCH[4]}
NEXT_BUILD=$((BUILD + 1))

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "⚠️  Working tree has uncommitted changes — the build will include them."
fi

echo
echo "Current version: $CURRENT"
echo "  1) Keep $CURRENT  (stores reject a build number that was already uploaded)"
echo "  2) Build only  → $MAJ.$MIN.$PAT+$NEXT_BUILD"
echo "  3) Patch       → $MAJ.$MIN.$((PAT + 1))+$NEXT_BUILD"
echo "  4) Minor       → $MAJ.$((MIN + 1)).0+$NEXT_BUILD"
echo "  5) Major       → $((MAJ + 1)).0.0+$NEXT_BUILD"
echo "  6) Custom"
read -r -p "Choose [1-6]: " CHOICE

case "$CHOICE" in
  1) NEW="$CURRENT" ;;
  2) NEW="$MAJ.$MIN.$PAT+$NEXT_BUILD" ;;
  3) NEW="$MAJ.$MIN.$((PAT + 1))+$NEXT_BUILD" ;;
  4) NEW="$MAJ.$((MIN + 1)).0+$NEXT_BUILD" ;;
  5) NEW="$((MAJ + 1)).0.0+$NEXT_BUILD" ;;
  6)
    read -r -p "New version (x.y.z+n): " NEW
    if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)$ ]]; then
      echo "❌ Invalid format."; pause_exit 1
    fi
    if [ "${BASH_REMATCH[1]}" -le "$BUILD" ]; then
      echo "❌ Build number must be greater than $BUILD."; pause_exit 1
    fi
    ;;
  *) echo "❌ Invalid choice."; pause_exit 1 ;;
esac

NAME="${NEW%+*}"; NUMBER="${NEW#*+}"

if [ "$NEW" != "$CURRENT" ]; then
  read -r -p "Update to $NEW in pubspec.yaml and Xcode? [y/N]: " OK
  [[ "$OK" =~ ^[Yy]$ ]] || { echo "Cancelled."; pause_exit 0; }

  # Edit both files with Python so only the intended lines/blocks change.
  /usr/bin/python3 - "$PUBSPEC" "$PBXPROJ" "$NAME" "$NUMBER" "$APP_BUNDLE_ID" <<'PY'
import re, sys
pubspec, pbxproj, name, number, bundle_id = sys.argv[1:]

s = open(pubspec).read()
s, n = re.subn(r'(?m)^version: .*$', f'version: {name}+{number}', s, count=1)
assert n == 1, 'pubspec version line not found'
open(pubspec, 'w').write(s)

# Only touch XCBuildConfiguration blocks of the main app target (exact bundle id),
# leaving RunnerTests and the widget extension (which uses $(FLUTTER_BUILD_*)) alone.
p = open(pbxproj).read()
block_re = re.compile(r'isa = XCBuildConfiguration;.*?name = \w+;', re.S)
changed = 0
def fix(m):
    global changed
    b = m.group(0)
    if f'PRODUCT_BUNDLE_IDENTIFIER = {bundle_id};' not in b:
        return b
    b = re.sub(r'MARKETING_VERSION = [^;]+;', f'MARKETING_VERSION = {name};', b)
    b = re.sub(r'CURRENT_PROJECT_VERSION = [^;]+;', f'CURRENT_PROJECT_VERSION = {number};', b)
    changed += 1
    return b
p = block_re.sub(fix, p)
assert changed == 3, f'expected 3 Runner build configs (Debug/Release/Profile), found {changed}'
open(pbxproj, 'w').write(p)
print(f'✅ pubspec.yaml and Xcode Runner (3 configs) set to {name} ({number})')
PY
fi

# ---------- Platform ----------
echo
echo "Build for:  1) iOS   2) Android   3) Both"
read -r -p "Choose [1-3, default 1]: " PLAT
PLAT="${PLAT:-1}"
[[ "$PLAT" =~ ^[123]$ ]] || { echo "❌ Invalid choice."; pause_exit 1; }

# ---------- Quality gates ----------
echo; echo "📦 flutter pub get..."
"$FLUTTER" pub get

echo "🔍 flutter analyze lib/ (errors fail the release)..."
"$FLUTTER" analyze lib/ --no-fatal-warnings --no-fatal-infos

read -r -p "Run flutter test? [Y/n]: " RUN_TESTS
if [[ ! "$RUN_TESTS" =~ ^[Nn]$ ]]; then
  echo "🧪 flutter test..."
  "$FLUTTER" test
fi

# ---------- Build ----------
if [[ "$PLAT" == "1" || "$PLAT" == "3" ]]; then
  echo; echo "🍎 Building iOS IPA $NEW..."
  "$FLUTTER" build ipa --release --build-name="$NAME" --build-number="$NUMBER"
  echo "✅ IPA:     build/ios/ipa/"
  echo "   Archive: build/ios/archive/Runner.xcarchive  (open in Xcode → Distribute App)"
fi

if [[ "$PLAT" == "2" || "$PLAT" == "3" ]]; then
  echo; echo "🤖 Building Android App Bundle $NEW..."
  "$FLUTTER" build appbundle --release --build-name="$NAME" --build-number="$NUMBER"
  echo "✅ AAB: build/app/outputs/bundle/release/app-release.aab"
fi

trap - ERR
echo
echo "🎉 Release build $NEW done."
if [ "$NEW" != "$CURRENT" ]; then
  echo "   Remember to commit: git commit -am \"chore(release): $NEW\""
fi
open build 2>/dev/null || true
pause_exit 0
