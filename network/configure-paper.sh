#!/usr/bin/env bash
set -Eeuo pipefail

# Paper must use a different port from Velocity.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAPER_DIR="$ROOT/runtime/paper"
PROPERTIES="$PAPER_DIR/server.properties"

if [[ ! -f "$PROPERTIES" ]]; then
  echo "Missing $PROPERTIES"
  echo "Start Paper once so it generates server.properties, then run this again."
  exit 1
fi

python3 - "$PROPERTIES" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
updates = {
    "server-port": "25566",
    "server-ip": "127.0.0.1",
}
seen = set()
result = []

for line in lines:
    stripped = line.strip()
    if "=" in stripped and not stripped.startswith("#"):
        key = stripped.split("=", 1)[0].strip()
        if key in updates:
            result.append(f"{key}={updates[key]}")
            seen.add(key)
            continue
    result.append(line)

for key, value in updates.items():
    if key not in seen:
        result.append(f"{key}={value}")

path.write_text("\n".join(result) + "\n")
print("Updated Paper server.properties:")
print("  server-ip=127.0.0.1")
print("  server-port=25566")
PY

echo
echo "Paper is now set to the private backend port 25566."
echo "Keep port 25566 private in the Codespaces Ports tab."
echo "Velocity remains the public entry point on port 25565."
