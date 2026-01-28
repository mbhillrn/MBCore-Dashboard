# WCURGUI - Prerequisites

## Required Tools

### Core Requirements
| Tool | Purpose | Install Command (Debian/Ubuntu) |
|------|---------|--------------------------------|
| `bash` | Shell (v4.0+) | Pre-installed |
| `jq` | JSON parsing for RPC responses | `sudo apt install jq` |
| `curl` | HTTP requests (RPC, APIs) | `sudo apt install curl` |

### Bitcoin Core
| Tool | Purpose | Notes |
|------|---------|-------|
| `bitcoin-cli` | RPC interface to bitcoind | Part of Bitcoin Core installation |
| `bitcoind` | Bitcoin daemon | Must be running for full functionality |

### Optional (for enhanced features)
| Tool | Purpose | Install Command |
|------|---------|-----------------|
| `ss` or `netstat` | Network connection info | `sudo apt install iproute2` |
| `systemctl` | Service management | Pre-installed on systemd systems |

## Detection Notes
- The program will auto-detect missing prerequisites on startup
- You will be prompted to install any missing required tools
- Optional tools enhance functionality but are not required

---
*This file is auto-updated as new features are added*
