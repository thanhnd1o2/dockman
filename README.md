# Dockman

> A lightweight, dependency-free alternative to Docker Desktop's GUI — manage your Docker resources right from the terminal.

Docker Desktop is powerful but heavy. Dockman gives you the same core visibility and control over containers, images, volumes, and networks through a fast, keyboard-driven TUI — no Electron, no background services, no license restrictions. Just Bash and your existing Docker CLI.

## Why Dockman

- **Lightweight** — pure Bash, zero install footprint beyond copying a few shell scripts
- **Easy to use** — arrow-key navigation, no commands to memorize
- **Works everywhere** — macOS (Bash 3.2+), Linux, any terminal
- **No dependencies** — only requires the Docker CLI you already have
- **Open source** — MIT licensed, easy to extend

## Features

- **Containers** — list, start, stop, restart, remove, view live logs, open shell, inspect, live stats
- **Images** — list, inspect, remove
- **Volumes** — list, inspect, remove
- **Networks** — list, inspect, remove (built-in networks protected)
- **Ports** — overview of all exposed port bindings across running containers
- **System** — Docker version, disk usage, container/image counts
- **Cleanup** — prune stopped containers, dangling images, unused volumes/networks, system prune
- **Engine startup** — detects stopped Docker Engine; offers to start via Colima or Lima

## Requirements

- Bash 3.2+ (macOS default or any Linux shell)
- Docker CLI

## Install

```bash
git clone https://github.com/fmaclen/dockman
cd dockman
sudo bash install.sh
```

This copies the library files to `/usr/local/lib/dockman/` and places a launcher at `/usr/local/bin/dockman`. Run it from anywhere:

```bash
dockman
```

## Usage

Or run directly without installing:

```bash
bash bin/dockman
```

## Keyboard shortcuts

| Key | Action |
|---|---|
| ↑ / k | Move up |
| ↓ / j | Move down |
| → / Enter | Select / open |
| ← / Esc | Back |
| Q | Quit |

## Uninstall

```bash
sudo bash uninstall.sh
```

This removes `/usr/local/bin/dockman` and `/usr/local/lib/dockman/`.

## Architecture

Layered modules with strict one-way dependencies:

```
bin/dockman          Entry point
lib/app.sh           Bootstrap loader (core → docker → screens)
lib/core/            terminal, keyboard, menu, helpers
lib/docker/          engine, containers, images, volumes, networks, ports
lib/screens/         root, containers, images, volumes, networks, ports, system, cleanup
```

Docker operation functions contain no UI or confirmation logic. All user interaction lives in the screens layer.

## License

MIT
