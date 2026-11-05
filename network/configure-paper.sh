#!/usr/bin/env bash
set -Eeuo pipefail

# Configure the two local server ports so they cannot collide:
# Velocity = public entry point :25565
# Paper    = private backend     :25566
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAPER_DIR="$ROOT/runtime/paper"
VELOCITY_DIR="$ROOT/runtime/velocity"
PROPERTIES="$PAPER_DIR/server.properties"
VELOCITY_CONFIG="$VELOCITY_DIR/velocity.toml"

if [[ ! -f "$PROPERTIES" ]]; then
  echo "Missing $PROPERTIES"
  echo "Start Paper once to generate server.properties, then stop it and rerun this script."
  exit 1
fi

if [[ ! -f "$VELOCITY_CONFIG" ]]; then
  echo "Missing $VELOCITY_CONFIG"
  echo "Start Velocity once to generate velocity.toml, then stop it and rerun this script."
  exit 1
fi

python3 - "$PROPERTIES" "$VELOCITY_CONFIG" <<'PY'
from pathlib import Path
import sys

paper_path = Path(sys.argv[1])
paper_lines = paper_path.read_text().splitlines()
paper_updates = {
    "server-port": "25566",
    "server-ip": "127.0.0.1",
}
seen = set()
result = []

for line in paper_lines:
    stripped = line.strip()
    if "=" in stripped and not stripped.startswith("#"):
        key = stripped.split("=", 1)[0].strip()
        if key in paper_updates:
            result.append(f"{key}={paper_updates[key]}")
            seen.add(key)
            continue
    result.append(line)

for key, value in paper_updates.items():
    if key not in seen:
        result.append(f"{key}={value}")

paper_path.write_text("\n".join(result) + "\n")

velocity_path = Path(sys.argv[2])
velocity_lines = velocity_path.read_text().splitlines()
section = ""
updated_bind = False
updated_lobby = False
updated_try = False
result = []

for line in velocity_lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        section = stripped[1:-1].strip()

    if section == "" and stripped.startswith("bind") and "=" in stripped and not stripped.startswith("#"):
        result.append('bind = "0.0.0.0:25565"')
        updated_bind = True
        continue

    if section == "servers" and stripped.startswith("lobby") and "=" in stripped and not stripped.startswith("#"):
        result.append('lobby = "127.0.0.1:25566"')
        updated_lobby = True
        continue

    if section == "servers" and stripped.startswith("try") and "=" in stripped and not stripped.startswith("#"):
        result.append('try = ["lobby"]')
        updated_try = True
        continue

    result.append(line)

if not updated_bind:
    raise SystemExit('Could not find Velocity bind setting; no Velocity changes saved.')
if not updated_lobby:
    raise SystemExit('Could not find [servers] lobby setting; no Velocity changes saved.')
if not updated_try:
    # Add try to the existing [servers] section, not to the end of the file.
    for index, line in enumerate(result):
        if line.strip() == "[servers]":
            result.insert(index + 1, 'try = ["lobby"]')
            updated_try = True
            break
if not updated_try:
    raise SystemExit('Could not find [servers] section; no Velocity changes saved.')

velocity_path.write_text("\n".join(result) + "\n")
print("Updated Paper:    127.0.0.1:25566")
print("Updated Velocity: 0.0.0.0:25565")
print("Velocity backend: 127.0.0.1:25566")
PY

echo
echo "Port configuration complete."
echo "Paper listens privately on 127.0.0.1:25566."
echo "Velocity listens on 0.0.0.0:25565 and routes to Paper."
echo "Keep only Velocity port 25565 public in Codespaces."
echo "Restart both servers for the changes to take effect."
