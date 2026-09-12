---
name: project_watch_order_playlists
description: Franchise watch-order playlist status — which use SmartLists (auto-refresh) vs manual curation, and what would trigger a rerun
metadata:
  type: project
---

9 franchise watch-order playlists built 2026-09-11/12: Macross, Steins;Gate, Monogatari, Gurren Lagann, Gundam Universal Century, Star Wars: The Clone Wars (all via SmartLists, auto-refreshing), plus Trigun, Votoms, .hack (manual `build_playlist.py`, plain playlists — fixed item IDs, do **not** auto-refresh).

**Why manual for the last three:** each needs a movie/OVA to slot mid-season (e.g. Trigun's Badlands Rumble between episodes 10 and 11), and no working external-list provider supports episode-level ordering — Trakt is the only one that does and it's dead (VIP-paywalled since 2026-07-30, see [[project_watch_order_playlists]] link to `ai/todo.md` #124). MDBList structurally cannot do it (only `Movie`/`Show` kinds exist in its data model, confirmed from the plugin's own source).

**How to apply:** Full status table, rerun triggers, and the external-list provider capability matrix live in `media/scripts/watch_orders/README.md` — read that before starting a new franchise (check if a curated external list already exists first) or before assuming an existing manual playlist needs attention (it only does if new content was acquired for that franchise, or a library item was deleted and recreated with a new ID — both rare). See `media/scripts/AGENTS.md` for the two scripts' entry points.
