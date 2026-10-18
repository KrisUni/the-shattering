#!/bin/bash
# Installs headless Godot 4.7.2 at ~/tools/godot so scripts/test.sh runs in cloud sessions.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

VERSION="4.7.2-stable"
BINARY="Godot_v${VERSION}_linux.x86_64"
SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
TOOLS="$HOME/tools"
DEST="$TOOLS/godot-4.7.2"

if [ ! -x "$DEST/$BINARY" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -sSfL -o "$tmp/godot.zip" \
    "https://github.com/godotengine/godot-builds/releases/download/${VERSION}/${BINARY}.zip"
  echo "$SHA512  $tmp/godot.zip" | sha512sum -c --quiet -
  mkdir -p "$DEST"
  unzip -q -o "$tmp/godot.zip" -d "$DEST"
fi

ln -sfn "$DEST/$BINARY" "$TOOLS/godot"

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export GODOT=\"$TOOLS/godot\"" >> "$CLAUDE_ENV_FILE"
fi
