#!/usr/bin/env bash
set -Eeuo pipefail

# Configure a local Paper backend behind Velocity with modern forwarding.
# Velocity = public entry point :25565
# Paper    = private backend     127.0.0.1:25566

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAPER_DIR="$ROOT/runtime/paper"
VELOCITY_DIR="$ROOT/runtime/velocity"
PROPERTIES="$PAPER_DIR/server.properties"
PAPER_GLOBAL="$PAPER_DIR/config/paper-global.yml"
VELOCITY_CONFIG="$VELOCITY_DIR/velocity.toml"
SECRET_FILE="$VELOCITY_DIR/forwarding.secret"

for file in "$PROPERTIES" "$PAPER_GLOBAL" "$VELOCITY_CONFIG"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing $file"
    echo "Start Paper and Velocity once to generate their configuration files, then stop both and rerun this script."
    exit 1
  fi
done

mkdir -p "$VELOCITY_DIR"
if [[ ! -s "$SECRET_FILE" ]]; then
  python3 -c 'import secrets; print(secrets.token_hex(32))' > "$SECRET_FILE"
  chmod 600 "$SECRET_FILE"
fi

python3 - "$PROPERTIES" "$PAPER_GLOBAL" "$VELOCITY_CONFIG" "$SECRET_FILE" <<'PY'
from pathlib import Path
import re
import sys

properties_path, paper_path, velocity_path, secret_path = map(Path, sys.argv[1:])
secret = secret_path.read_text().strip()
if not secret:
    raise SystemExit("Forwarding secret is empty; refusing to configure.")

def set_properties(path, updates):
    lines = path.read_text().splitlines()
    seen = set()
    out = []
    for line in lines:
        stripped = line.strip()
        if "=" in stripped and not stripped.startswith("#"):
            key = stripped.split("=", 1)[0].strip()
            if key in updates:
                out.append(f"{key}={updates[key]}")
                seen.add(key)
                continue
        out.append(line)
    for key, value in updates.items():
        if key not in seen:
            out.append(f"{key}={value}")
    path.write_text("\n".join(out) + "\n")

# Paper must not authenticate players itself; Velocity authenticates them.
set_properties(properties_path, {
    "server-port": "25566",
    "server-ip": "127.0.0.1",
    "online-mode": "false",
})

# Update only the proxies.velocity block in Paper's global config.
lines = paper_path.read_text().splitlines()
out = []
in_proxies = False
in_velocity = False
proxies_indent = None
velocity_indent = None
seen = set()
updates = {
    "enabled": "true",
    "online-mode": "true",
    "secret": "'" + secret + "'",
}
for line in lines:
    stripped = line.strip()
    indent = len(line) - len(line.lstrip(" "))

    if stripped and not stripped.startswith("#"):
        if indent == 0:
            in_proxies = stripped == "proxies:"
            in_velocity = False
            proxies_indent = 0 if in_proxies else None
            velocity_indent = None
        elif in_proxies and indent == 2 and stripped == "velocity:":
            in_velocity = True
            velocity_indent = indent
            seen = set()
            out.append(line)
            continue
        elif in_proxies and indent == 2 and stripped.endswith(":"):
            in_velocity = False
            velocity_indent = None
        elif in_velocity and indent <= velocity_indent:
            in_velocity = False

    if in_velocity and indent == 4 and ":" in stripped and not stripped.startswith("#"):
        key = stripped.split(":", 1)[0].strip()
        if key in updates:
            out.append("    " + key + ": " + updates[key])
            seen.add(key)
            continue
    out.append(line)

if not any(line.strip() == "proxies:" for line in lines):
    raise SystemExit("Could not find top-level 'proxies:' in paper-global.yml.")
if not any(line.strip() == "velocity:" and len(line) - len(line.lstrip(" ")) == 2 for line in lines):
    raise SystemExit("Could not find 'proxies.velocity:' in paper-global.yml.")

# Re-scan the updated text and add any missing keys inside proxies.velocity.
lines = out
out = []
in_proxies = False
in_velocity = False
velocity_end = None
for line in lines:
    stripped = line.strip()
    indent = len(line) - len(line.lstrip(" "))
    if stripped and not stripped.startswith("#"):
        if indent == 0:
            in_proxies = stripped == "proxies:"
            in_velocity = False
        elif in_proxies and indent == 2 and stripped == "velocity:":
            in_velocity = True
            velocity_end = len(out) + 1
        elif in_proxies and indent == 2 and stripped.endswith(":"):
            in_velocity = False
        elif in_velocity and indent <= 2:
            in_velocity = False
    out.append(line)
    if in_velocity and indent == 2 and stripped == "velocity:":
        pass

# Find the velocity block and insert missing keys before the next sibling/top-level section.
start = next(i for i, line in enumerate(out) if line.strip() == "velocity:" and len(line) - len(line.lstrip(" ")) == 2)
end = start + 1
while end < len(out):
    line = out[end]
    s = line.strip()
    ind = len(line) - len(line.lstrip(" "))
    if s and not s.startswith("#") and ind <= 2:
        break
    end += 1
block = out[start+1:end]
present = {line.strip().split(":",1)[0] for line in block if line.strip() and not line.strip().startswith("#") and ":" in line}
missing = [f"    {key}: {value}" for key, value in updates.items() if key not in present]
out[end:end] = missing
paper_path.write_text("\n".join(out) + "\n")

# Configure Velocity's listener, backend, and authenticated modern forwarding.
lines = velocity_path.read_text().splitlines()
out = []
section = ""
updates_root = {
    "bind": '"0.0.0.0:25565"',
    "online-mode": "true",
    "player-info-forwarding-mode": '"modern"',
    "forwarding-secret-file": '"forwarding.secret"',
}
seen_root = set()
seen_lobby = False
seen_try = False
for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        section = stripped[1:-1].strip()
    if section == "" and "=" in stripped and not stripped.startswith("#"):
        key = stripped.split("=", 1)[0].strip()
        if key in updates_root:
            out.append(f"{key} = {updates_root[key]}")
            seen_root.add(key)
            continue
    if section == "servers" and stripped.startswith("lobby") and "=" in stripped and not stripped.startswith("#"):
        out.append('lobby = "127.0.0.1:25566"')
        seen_lobby = True
        continue
    if section == "servers" and stripped.startswith("try") and "=" in stripped and not stripped.startswith("#"):
        out.append('try = ["lobby"]')
        seen_try = True
        continue
    out.append(line)

for key, value in updates_root.items():
    if key not in seen_root:
        out.insert(0, f"{key} = {value}")
if not seen_lobby or not seen_try:
    section_index = next((i for i, line in enumerate(out) if line.strip() == "[servers]"), None)
    if section_index is None:
        raise SystemExit("Could not find [servers] in velocity.toml.")
    end = section_index + 1
    while end < len(out) and not out[end].strip().startswith("["):
        end += 1
    block = out[section_index+1:end]
    if not seen_lobby:
        block.append('lobby = "127.0.0.1:25566"')
    if not seen_try:
        block.append('try = ["lobby"]')
    out[section_index+1:end] = block

velocity_path.write_text("\n".join(out) + "\n")
print("Paper:    127.0.0.1:25566 (private; online-mode=false)")
print("Velocity: 0.0.0.0:25565 (proxy online-mode=true)")
print("Forwarding: modern (matching secret configured on both sides)")
print("Backend:  127.0.0.1:25566")
PY

chmod 600 "$SECRET_FILE"
echo
echo "Network configuration complete."
echo "Keep only Velocity port 25565 public in Codespaces."
echo "Keep Paper port 25566 private."
echo "Do not share network/runtime/velocity/forwarding.secret."
echo "Restart Paper and Velocity for the changes to take effect."
