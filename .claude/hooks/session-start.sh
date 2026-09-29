#!/bin/bash
# Claude Code on the web 세션 시작 시 Flutter SDK 를 설치하고 의존성을 받는다.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION="3.47.5"
FLUTTER_DIR="/opt/flutter"
ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"

installed_version() {
  local f="$FLUTTER_DIR/bin/cache/flutter.version.json"
  if [ -x "$FLUTTER_DIR/bin/flutter" ] && [ -f "$f" ]; then
    sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' "$f" | head -1
  else
    echo ""
  fi
}

if [ "$(installed_version)" != "$FLUTTER_VERSION" ]; then
  echo "Installing Flutter $FLUTTER_VERSION to $FLUTTER_DIR ..."
  rm -rf "$FLUTTER_DIR"
  mkdir -p /opt
  curl -sSL --retry 3 -o "/opt/$ARCHIVE" "$URL"
  tar -xJf "/opt/$ARCHIVE" -C /opt
  rm -f "/opt/$ARCHIVE"
fi

git config --global --add safe.directory "$FLUTTER_DIR" || true
export PATH="$FLUTTER_DIR/bin:$PATH"

# 세션 전체에서 flutter/dart 를 쓸 수 있게 PATH 를 남긴다.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"
flutter pub get
echo "Flutter ready."
