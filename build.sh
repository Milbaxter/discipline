#!/bin/bash
# Rebuild the discipline binary and refresh /Applications/Discipline.app.
# Some Command Line Tools installs ship a duplicate SwiftBridging modulemap
# that breaks all Swift compiles; if present, work around it with a VFS
# overlay (see toolchain-fix/).
set -euo pipefail
cd "$(dirname "$0")"

OVERLAY_ARGS=()
if [ -f /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap ]; then
  sed "s|@EMPTY_MODULEMAP@|$PWD/toolchain-fix/empty.modulemap|" \
    toolchain-fix/overlay.yaml.in > toolchain-fix/overlay.yaml
  OVERLAY_ARGS=(-vfsoverlay toolchain-fix/overlay.yaml)
fi

mkdir -p bin
swiftc ${OVERLAY_ARGS[@]+"${OVERLAY_ARGS[@]}"} -O -o bin/discipline Sources/discipline/*.swift

APP="/Applications/Discipline.app"
if ! mkdir -p "$APP/Contents/MacOS" 2>/dev/null; then
  APP="$HOME/Applications/Discipline.app"
  mkdir -p "$APP/Contents/MacOS"
fi
cp Info.plist "$APP/Contents/Info.plist"
cp bin/discipline "$APP/Contents/MacOS/discipline"
codesign --force -s - "$APP" >/dev/null 2>&1 || true

echo "built: $APP"
