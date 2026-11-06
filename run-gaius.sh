#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$ROOT/port/runner.env"
CONFIG_EXAMPLE="$ROOT/port/runner.env.example"

# Create a local settings file once. It is ignored by Git and reused next time.
if [[ ! -f "$CONFIG" ]]; then
  cp "$CONFIG_EXAMPLE" "$CONFIG"
  echo "Created saved runner settings: $CONFIG"
fi

# This file is a local shell config controlled by the Codespace owner.
# shellcheck disable=SC1090
source "$CONFIG"

PROFILE="${GAIUS_VERSION_PROFILE_PATH:-versions/26.3.json}"
BIND="${GAIUS_RUNNER_BIND:-0.0.0.0}"
PORT="${GAIUS_RUNNER_PORT:-8081}"
HEAP="${GAIUS_TEAVM_MAX_HEAP:-10g}"
BUILD="${GAIUS_BUILD_ON_START:-1}"

export GAIUS_VERSION_PROFILE_PATH="$PROFILE"

case "$PROFILE" in
  versions/*.json) PROFILE_FILE="$ROOT/port/$PROFILE" ;;
  *) echo "Profile must be inside port/versions (example: versions/26.3.json)" >&2; exit 2 ;;
esac
[[ -s "$PROFILE_FILE" ]] || { echo "Missing profile: $PROFILE_FILE" >&2; exit 1; }
VERSION="$(jq -er '.id' "$PROFILE_FILE")"

for cmd in java curl jq unzip node python3; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

JAVA_MAJOR="$(java -version 2>&1 | awk -F '[".]' '/version/ {print $2; exit}')"
if [[ -z "$JAVA_MAJOR" || "$JAVA_MAJOR" -lt 25 ]]; then
  echo "Gaius profile $VERSION requires JDK 25+. Current Java: $(java -version 2>&1 | head -n 1)" >&2
  exit 1
fi

echo "Gaius Client Runner — Minecraft $VERSION"
echo "Saved settings: $CONFIG"
echo "Website: http://localhost:$PORT"
echo "Bind: $BIND | TeaVM heap: $HEAP"

if [[ "$BUILD" == "1" ]]; then
  echo "[1/3] Fetching and verifying official Minecraft files/assets..."
  bash "$ROOT/port/scripts/fetch-version.sh"

  echo "[2/3] Preparing the named Minecraft client..."
  bash "$ROOT/port/scripts/remap-client.sh"

  echo "[3/3] Compiling the Gaius browser client and release site..."
  echo "Note: 16 GB Codespaces may still run out of memory during TeaVM compilation."
  GAIUS_TEAVM_MAX_HEAP="$HEAP" bash "$ROOT/port/scripts/build-version-release.sh" "$PROFILE"
else
  echo "Build-on-start is disabled; reusing the existing build."
fi

DIST="$ROOT/port/web/dist/$VERSION"
[[ -s "$DIST/index.html" ]] || {
  echo "Build output is missing: $DIST/index.html" >&2
  echo "Enable GAIUS_BUILD_ON_START=1 in $CONFIG and run again." >&2
  exit 1
}

echo "Build is ready. Launching the Gaius website..."
echo "Open the forwarded port $PORT in the Codespaces Ports tab."
cd "$ROOT"
exec python3 -m http.server "$PORT" --bind "$BIND" --directory "$DIST"
