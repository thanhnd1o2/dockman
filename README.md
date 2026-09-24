# Dockman

A dependency-free interactive TUI for managing Docker containers, images, volumes, and networks. Written entirely in Bash (3.2 compatible) — no external libraries required.

## Features

- **Containers** — list, start, stop, restart, remove, view live logs, open shell, inspect, live stats
- **Images** — list, inspect, remove
- **Volumes** — list, inspect, remove
- **Networks** — list, inspect, remove (built-in networks protected)
- **System** — Docker version, disk usage, container/image counts
- **Cleanup** — prune stopped containers, dangling images, unused volumes/networks, system prune
- **Engine startup** — detects stopped Docker Engine; offers to start via Lima or Colima

## Requirements

- Bash 3.2+ (macOS default or any Linux shell)
- Docker CLI

## Install

```bash
git clone <repo-url> dockman
cd dockman
bash install.sh
```

This creates a symlink at `/usr/local/bin/dockman` pointing to `bin/dockman`. Edits to the source take effect immediately — no reinstall needed.

## Usage

```bash
dockman
```

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
bash uninstall.sh
```

## Architecture

Layered modules with strict one-way dependencies:

```
bin/dockman          Entry point
lib/app.sh           Bootstrap loader (core → docker → screens)
lib/core/            terminal, keyboard, menu, helpers
lib/docker/          engine, containers, images, volumes, networks
lib/screens/         root, containers, images, volumes, networks, system, cleanup
```

Docker operation functions contain no UI or confirmation logic. All user interaction lives in the screens layer.

## License

MIT
