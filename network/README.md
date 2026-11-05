# MB Software House — Minecraft Network Runtime

This folder contains setup tooling for the private test network built around:

- **Paper 26.3** — backend game server
- **Velocity** — front-facing Java proxy
- **Gaius** — browser client source in the parent repository

## Install the server software

Run this from the repository root in Codespaces:

```bash
bash network/setup.sh
```

The installer downloads official PaperMC builds through the PaperMC Fill API,
verifies each JAR against the SHA-256 checksum returned by the API, and places
the files here:

```text
network/runtime/
├── paper/paper.jar
└── velocity/velocity.jar
```

The runtime directory and JAR files are ignored by Git. They are downloaded
inside the Codespace and are **not committed to the repository**.

## Requirements

- Java 25 or newer
- `curl`, `jq`, and `sha256sum`
- Network access to PaperMC's Fill download service

## Important

The installer only downloads and verifies the two server JARs. It does not
generate the proxy/backend configuration or start the servers yet. Those
settings must be configured together so that Velocity is the public entry
point and Paper only accepts connections from the local proxy.

Paper 26.3 stable builds are selected explicitly. Velocity uses the latest
recommended build when available, then the latest stable build; if neither is
available, the installer uses the newest build returned by PaperMC.

Official references:

- [PaperMC downloads service](https://docs.papermc.io/misc/downloads-service/)
- [Paper getting started](https://docs.papermc.io/paper/getting-started/)
- [Velocity getting started](https://docs.papermc.io/velocity/getting-started/)
