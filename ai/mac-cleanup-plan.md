# Mac Cleanup & MCP Migration Plan

Diagnosed 2026-06-12. M1 MacBook Air 8GB was RAM-exhausted (80MB free, 4.2GB swap) due to accumulated background processes from Claude tooling, Adobe CC, and browser bloat.

## Already Done

- [x] Removed `macos-mcp` Claude Desktop extension (was burning 37% CPU)
- [x] Disabled Adobe Creative Cloud launch at login
- [x] Enabled Brave Memory Saver (`brave://settings/system`)
- [x] Removed Brave extensions not in active use
- [x] Removed mempalace: hooks, plugin, `~/.mempalace/` data
  - Backup at `~/mempalace-backup-20260612.tar.gz`

## Background Launch Agents to Audit

These run persistently and may not be needed. Disable via `launchctl unload <plist>` or remove the app.

### High priority (consider removing)
| Agent | Plist | Notes |
|---|---|---|
| Adobe CC (×4) | `/Library/LaunchAgents/com.adobe.*`, `/Users/kieran/Library/LaunchAgents/com.adobe.*` | 4 separate Adobe agents still registered. Full uninstall of CC removes them. Worth doing if you don't use Adobe apps regularly. |
| GOG Galaxy | `/Library/LaunchAgents/com.gog.galaxy.commservice.plist` | Background service for GOG game library. Disable if not actively gaming. |
| Epic Games Launcher | `~/Library/LaunchAgents/com.epicgames.launcher.plist` | Persistent background agent. Disable if not using Epic. |
| Steam clean | `~/Library/LaunchAgents/com.valvesoftware.steamclean.plist` | Periodic cleanup job, low impact but unnecessary if not gaming. |
| Google Keystone (×2) | `/Library/LaunchAgents/com.google.keystone.*` | Google auto-update service. Present even if Chrome isn't installed. Can be removed. |
| Microsoft Update | `/Library/LaunchAgents/com.microsoft.update.agent.plist` | MS Office updater. Remove if not using Office. |

### Keep
| Agent | Notes |
|---|---|
| Dropbox (×3) | Active use assumed |
| token-optimizer dashboard | Kept intentionally |
| Logos indexer | Active use assumed |
| CCleaner | Active use |

## Claude Desktop Extensions (currently installed)

| Extension | Status | Notes |
|---|---|---|
| `ant.anthropic.filesystem` | Keep | Core file access MCP |
| `gh.cursortouch.macos-mcp` | **Remove** | Already decided — was burning CPU, uninstall from Extensions UI |
| `gh.k6l3.osascript` | Review | OSA script execution — do you use this? If not, remove |

## MCP Migration to TrueNAS

Running MCPs locally consumes RAM/CPU on every Claude session. TrueNAS (192.168.20.22) is always-on and has headroom.

### Good candidates to move to NAS
- **Any stateless tool MCPs** (filesystem access to NAS paths, API wrappers, search tools)
- **mempalace** if re-enabled — the SQLite palace and mining jobs belong on NAS storage
- Any MCP that accesses NAS data anyway (it's silly to proxy through the Mac)

### Must stay local
| MCP | Why |
|---|---|
| `computer-use` | Needs Mac display/input access |
| `Claude_in_Chrome` | Needs local browser DOM access |
| `macos-mcp` | Mac-specific APIs (now removed) |
| `osascript` | Mac-only |
| `filesystem` (for local paths) | Local file access |

### Migration approach
Run MCPs as Docker containers on TrueNAS, expose via SSE/HTTP, point Claude Desktop at `http://192.168.20.22:<port>` instead of `npx`/`uvx` local process.

Most MCP servers support `--transport sse` or `--transport http` for remote connections.

Example compose pattern (TrueNAS stack):
```yaml
services:
  mcp-server:
    image: <mcp-image>
    command: ["--transport", "sse", "--port", "8080"]
    ports:
      - "8080:8080"
```

Then in `~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "my-server": {
      "url": "http://192.168.20.22:8080/sse"
    }
  }
}
```

## Homebrew Packages to Review

Current install: 49 packages. Notable ones worth auditing:
- `merve` — what is this? (`brew info merve`)
- `nmap` — network scanner, probably intentional
- `ffmpeg` — large, needed for media work
- `sdl2` — graphics lib, likely a dependency

No services are currently running via `brew services` — good, no daemon overhead there.

## npm Global Packages

- `@toon-format/cli` — Claude tooling, low overhead
- `npm` itself

Clean, nothing to remove here.
