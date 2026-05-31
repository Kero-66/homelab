# Recyclarr Rules

- **API Keys**: Never hardcode — use `!secret` tags referencing `secrets.yml`
- **Profiles**: Map to existing: `Anime (1080p)`, `Standard (1080p)`, `Ultra-HD (4K)` — do NOT create new profiles via templates
- **Anime Audio**: Penalize English-only dubs with score `-10000` on "Dubs Only" custom format
- **Warnings**: Ignore "missing profile definitions" warnings for template-default names (e.g. `Remux-1080p - Anime`)
- **Naming**: Use `WEBDL-1080p` / `WEBDL-2160p` style for quality targets
