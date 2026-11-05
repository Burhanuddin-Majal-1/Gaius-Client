#!/usr/bin/env bash
set -Eeuo pipefail

# Downloads official Paper + Velocity server jars into ignored runtime folders.
# The jars/worlds are not committed to Git.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/runtime"
API="https://fill.papermc.io/v3"
MC_VERSION="26.3"
USER_AGENT="MB-Software-House-Setup/1.0 (https://github.com/Burhanuddin-Majal-1/Gaius-Client)"

for cmd in curl jq sha256sum java; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

JAVA_VERSION="$(java -version 2>&1 | awk -F '[".]' '/version/ { print ($2 == "1" ? $3 : $2); exit }')"
if [[ -z "$JAVA_VERSION" || "$JAVA_VERSION" -lt 25 ]]; then
  echo "Java 25 or newer is required by Paper 26.3 and current Velocity." >&2
  java -version 2>&1 || true
  exit 1
fi

download_verified() {
  local url="$1" expected_sha="$2" destination="$3"
  local temporary="${destination}.download"

  mkdir -p "$(dirname "$destination")"
  rm -f "$temporary"

  echo "Downloading $(basename "$destination")..."
  curl --fail --location --retry 3 --retry-delay 2 \
    --output "$temporary" "$url"

  printf '%s  %s\n' "$expected_sha" "$temporary" | sha256sum --check --status || {
    rm -f "$temporary"
    echo "SHA-256 verification failed for $destination" >&2
    exit 1
  }

  mv "$temporary" "$destination"
  echo "Verified: $destination"
}

echo "== Paper $MC_VERSION =="
PAPER_BUILDS="$(curl --fail --silent --show-error --header "User-Agent: $USER_AGENT" \
  "$API/projects/paper/versions/$MC_VERSION/builds")"

PAPER_META="$(printf '%s' "$PAPER_BUILDS" | jq -cer \
  'first(.[] | select(.channel == "STABLE"))')"
PAPER_URL="$(printf '%s' "$PAPER_META" | jq -er '.downloads["server:default"].url')"
PAPER_SHA="$(printf '%s' "$PAPER_META" | jq -er '.downloads["server:default"].checksums.sha256')"
PAPER_BUILD="$(printf '%s' "$PAPER_META" | jq -er '.id')"

download_verified "$PAPER_URL" "$PAPER_SHA" "$RUNTIME/paper/paper.jar"
printf 'Paper build: %s (Minecraft %s)\n' "$PAPER_BUILD" "$MC_VERSION"

echo
echo "== Velocity =="
VELOCITY_PROJECT="$(curl --fail --silent --show-error --header "User-Agent: $USER_AGENT" \
  "$API/projects/velocity")"
VELOCITY_VERSION="$(printf '%s' "$VELOCITY_PROJECT" | jq -er '.versions | to_entries[0].value[0]')"
VELOCITY_BUILDS="$(curl --fail --silent --show-error --header "User-Agent: $USER_AGENT" \
  "$API/projects/velocity/versions/$VELOCITY_VERSION/builds")"

VELOCITY_META="$(printf '%s' "$VELOCITY_BUILDS" | jq -cer \
  '([.[] | select(.channel == "RECOMMENDED")][0] // [ .[] | select(.channel == "STABLE") ][0] // .[0])')"
VELOCITY_URL="$(printf '%s' "$VELOCITY_META" | jq -er '.downloads["server:default"].url')"
VELOCITY_SHA="$(printf '%s' "$VELOCITY_META" | jq -er '.downloads["server:default"].checksums.sha256')"
VELOCITY_BUILD="$(printf '%s' "$VELOCITY_META" | jq -er '.id')"
VELOCITY_CHANNEL="$(printf '%s' "$VELOCITY_META" | jq -er '.channel')"

download_verified "$VELOCITY_URL" "$VELOCITY_SHA" "$RUNTIME/velocity/velocity.jar"
printf 'Velocity: %s build %s (%s channel)\n' "$VELOCITY_VERSION" "$VELOCITY_BUILD" "$VELOCITY_CHANNEL"

echo
echo "Done. Both verified JARs are in network/runtime/."
echo "They are intentionally ignored by Git and will not be committed."
echo "Next: generate/configure Velocity and Paper before starting the network."
