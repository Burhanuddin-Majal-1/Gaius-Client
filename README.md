# MB Software House — Private Minecraft Network

Private test setup using **Velocity + Paper 26.3** in GitHub Codespaces, with the Gaius Client source in this repository.

> This repository is a development setup, not a permanent public server host. Codespaces can stop when idle, and forwarded addresses can change.

## 1. Create the Codespace

1. Open this repository on GitHub.
2. Select **Code → Codespaces → Create codespace on main**.
3. Wait for the VS Code browser workspace to finish loading.
4. Open **Terminal → New Terminal**.

Use a Codespace with enough memory for both Java processes. Paper and Velocity require **Java 25 or newer**.

Check Java:

```bash
java -version
```

If the version is below 25, switch to a Codespace/devcontainer image that provides JDK 25 before continuing.

## 2. Get the server JAR files

The server files belong in:

```text
network/runtime/
├── paper/paper.jar
└── velocity/velocity.jar
```

If the files are not already present, open the repository's **Actions** tab, select **Download Paper + Velocity**, choose Minecraft version **26.3**, and run the workflow. Return to the Codespace and run:

```bash
git pull
ls -lh network/runtime/paper/paper.jar network/runtime/velocity/velocity.jar
```

If the workflow is unavailable, the alternative installer is:

```bash
bash network/setup.sh
```

## 3. Generate Paper's first-run files and accept the EULA

Start Paper once:

```bash
cd /workspaces/Gaius-Client/network/runtime/paper
java -Xms1G -Xmx2G -jar paper.jar --nogui
```

On the first run, Paper creates `eula.txt` and stops if the EULA has not been accepted. Read the Minecraft EULA at https://www.minecraft.net/eula. Only if you agree, edit the file:

```bash
nano eula.txt
```

Change `eula=false` to `eula=true`, save with **Ctrl+O**, press **Enter**, then exit with **Ctrl+X**.

Start Paper again so it creates `server.properties`. Once it finishes starting, stop it with **Ctrl+C**.

## 4. Set Paper to the private backend port

From the repository root:

```bash
cd /workspaces/Gaius-Client
bash network/configure-paper.sh
```

This now configures **both** server files in one go: Paper listens privately on **127.0.0.1:25566**, while Velocity listens on **0.0.0.0:25565** and routes to Paper at **127.0.0.1:25566**. Stop both servers before running the script. Do not make Paper port 25566 public.

## 5. Configure and start Velocity

The configuration script updates the Velocity bind and Paper backend address automatically. You can inspect the result here:

```bash
nano network/runtime/velocity/velocity.toml
```

Expected values:

```toml
bind = "0.0.0.0:25565"

[servers]
lobby = "127.0.0.1:25566"
try = ["lobby"]
```

Keep any other existing settings. Velocity modern forwarding and Paper's matching forwarding secret/configuration must also be set before treating the network as ready for player connections; do not expose the Paper backend directly.

## 6. Run both servers

Keep Paper running in one terminal:

```bash
cd /workspaces/Gaius-Client/network/runtime/paper
java -Xms1G -Xmx2G -jar paper.jar --nogui
```

Open a **second terminal** and start Velocity:

```bash
cd /workspaces/Gaius-Client/network/runtime/velocity
java -Xms512M -Xmx1G -jar velocity.jar
```

Do not start a second copy of either server. If you see **Address already in use**, check whether a server is already running before changing ports.

## 7. Codespaces port visibility

Open the **Ports** tab in the Codespace.

- **25565 — Velocity:** set to **Public** only if you intend to allow external connections.
- **25566 — Paper:** keep private; it is the backend used by Velocity.
- **8080 and 8081:** reserve for the Gaius bridge/client web services only when those services are configured and running. They are not started by Paper or Velocity.

Codespaces forwarding URLs are temporary and are not a permanent server address. The Codespace must remain running for the server to be reachable.

## Quick commands

From the repository root:

```bash
# Configure Paper after its first successful startup
bash network/configure-paper.sh

# Terminal 1: Paper
cd network/runtime/paper
java -Xms1G -Xmx2G -jar paper.jar --nogui

# Terminal 2: Velocity
cd network/runtime/velocity
java -Xms512M -Xmx1G -jar velocity.jar
```

## Important notes

- Paper 26.3 and current Velocity need Java 25+.
- Keep the Paper backend on localhost port 25566; expose only Velocity on 25565.
- A running Velocity proxy and Paper server do not, by themselves, complete the Gaius browser-client bridge setup. Configure and run the Gaius bridge/client components separately.
- Follow Minecraft's EULA and the relevant software licenses.
- For setup problems, open a GitHub Issue and include the relevant startup log (remove secrets first).
