# MB Software House — Private Minecraft Network

Private test setup using **Velocity + Paper 26.3** in GitHub Codespaces, with the Gaius Client source in this repository.

> This repository is a development setup, not a permanent public server host. Codespaces can stop when idle, and forwarded addresses can change.

## Gaius Client Runner (compile + launch)

The repository includes a one-command runner for the Minecraft 26.3 browser client. In the Codespace terminal, run:

```bash
cd /workspaces/Gaius-Client && git pull && chmod +x run-gaius.sh && ./run-gaius.sh
```

On first run it creates `port/runner.env` from `port/runner.env.example`. That local file remembers the selected Minecraft profile, website port, bind address, build-on-start setting, and TeaVM heap for future runs. It is ignored by Git and is not committed.

The runner fetches and verifies the official game files, prepares the client, compiles the browser release, then serves the generated site on port **8081**. Open the forwarded **8081** port from the Codespaces Ports tab. Stop the website with **Ctrl+C**.

Default settings target Minecraft **26.3** and use a **10 GB TeaVM heap**. A 4-core/16-GB Codespace may still run out of memory: the project recommends at least 32 GB physical memory for a full build. If compilation fails from memory pressure, lower `GAIUS_TEAVM_MAX_HEAP` in `port/runner.env` (for example, `8g`) and retry. After a successful build, set `GAIUS_BUILD_ON_START="0"` in that file to launch the existing build without compiling again.

This runner launches the browser website only. Multiplayer still uses the configured Gaius RelayNode and a reachable Java server; it does not start Paper, Velocity, or a RelayNode.

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

Start Paper again so it creates `server.properties` and `config/paper-global.yml`. Once it finishes starting, stop it with **Ctrl+C**. Then start Velocity once from `network/runtime/velocity` so it creates `velocity.toml`, and stop it with **Ctrl+C**.

## 4. Set Paper to the private backend port

From the repository root:

```bash
cd /workspaces/Gaius-Client
bash network/configure-paper.sh
```

This configures both ports and **Velocity modern forwarding**. It creates a private random `forwarding.secret`, configures Velocity to authenticate players and forward their identity, and configures Paper to verify that same secret. Paper listens privately on **127.0.0.1:25566**; Velocity listens on **0.0.0.0:25565**. Stop both servers before running the script. Do not make Paper port 25566 public, and never share `network/runtime/velocity/forwarding.secret`.

## 5. Configure and start Velocity

The configuration script updates the Velocity bind and Paper backend address automatically. You can inspect the result here:

```bash
nano network/runtime/velocity/velocity.toml
```

Expected important values:

```toml
bind = "0.0.0.0:25565"

[servers]
lobby = "127.0.0.1:25566"
try = ["lobby"]
```

Keep any other existing settings. The script also sets Paper's `proxies.velocity.enabled: true`, matching `online-mode: true` and the same secret, plus `online-mode=false` in Paper's `server.properties`. The backend stays bound to localhost and verifies Velocity's forwarding signature. Do not expose Paper directly.

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
