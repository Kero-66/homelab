---
name: feedback_check_correct_files
description: "Always check truenas/stacks/ for live config files, not networking/.config/ — those are reference only"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 284427c0-cb60-48cf-8132-99aabb636554
---

The live TrueNAS configs are in `truenas/stacks/` in the repo. The `networking/.config/` directory contains reference/documentation copies that are NOT pushed to TrueNAS.

**Why:** Pushed the wrong Caddyfile (`networking/.config/caddy/Caddyfile`) to TrueNAS and broke all services. The correct file is `truenas/stacks/caddy/Caddyfile`.

**How to apply:** Before SCPing any config to TrueNAS, always source from `truenas/stacks/<service>/`. Never push from `networking/.config/`.
