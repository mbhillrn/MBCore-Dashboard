# WCURGUI - Project Progress

## Overview
Bitcoin Core monitoring and management GUI - terminal-based dashboard.

## Completed Features

### v0.1 - Core Detection System
- **Bitcoin Core Detection**: Auto-detects bitcoind installation, datadir, conf, and RPC auth
  - Checks running processes first (most reliable)
  - Interrogates systemd services if applicable
  - Falls back to common install locations
  - Validates via RPC probe
  - Caches successful config for fast subsequent runs
- **Prerequisites Checker**: Validates required tools are installed, offers to install missing ones
- **UI Library**: Color-coded output, progress indicators, bordered sections

## In Progress
- None

## Planned Features
- Peer map with geolocation
- Peer list with connection stats
- Chain/mining status display
- Mempool graphs
- System metrics (CPU/RAM/disk)
- Security scanner
- Price/wallet integration

---
*Last updated: Initial setup*
