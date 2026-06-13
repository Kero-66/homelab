# Recyclarr Rules

- **API Keys**: Never hardcode — use `!secret` tags referencing `secrets.yml`
- **Profiles**: Map to existing: `Anime (1080p)`, `Standard (1080p)`, `Ultra-HD (4K)` — do NOT create new profiles via templates
- **Anime Audio**: Penalize English-only dubs with score `-10000` on "Dubs Only" custom format
- **Warnings**: Ignore "missing profile definitions" warnings for template-default names (e.g. `Remux-1080p - Anime`)
- **Naming**: Use `WEBDL-1080p` / `WEBDL-2160p` style for quality targets
- **Local custom formats**: Define in `truenas/stacks/recyclarr/custom-formats/<name>.json` with a unique `trash_id` prefixed `homelab-`. Add `resource_providers` to `settings.yml` pointing to `/config/custom-formats`. Reference `trash_id` in `recyclarr.yml` like any TRaSH CF.
- **Adopting manual CFs**: If a CF with the same name was manually created in Sonarr/Radarr before recyclarr knew about it, run `recyclarr state repair --adopt` — otherwise sync fails with "CFs with matching names already exist"
- **delete_old_custom_formats: true** — any CF not in recyclarr.yml will be deleted on next sync; always add CFs to recyclarr before or at the same time as creating them manually
