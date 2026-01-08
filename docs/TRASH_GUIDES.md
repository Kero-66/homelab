# TRaSH Guides Integration

This repository implements a subset of the [TRaSH Guides](https://trash-guides.info/) to automate high-quality media collection in Sonarr and Radarr.

---

## 1. How it Works

TRaSH guides provide **Custom Formats (CF)** and **Scoring** systems. Instead of just "1080p is better than 720p", this system lets us score specific release groups, codecs, or features (e.g., `10bit`, `Dual Audio`, `x265`).

### Relationship with Huntarr

- **TRaSH (The Brain)**: Defines *what* is a good file and *how much better* one file is compared to another.
- **Huntarr (The Motor)**: Triggers the *when* (periodic searches). Huntarr asks Sonarr/Radarr if there are any "upgrades" available based on the scores defined by the TRaSH profiles.

**Together, they ensure your library is always upgrading to the best possible version without manual intervention.**

---

## 2. Currently Implemented

### Sonarr (Anime Focused)

- **Script**: [scripts/sonarr_trash_apply.sh](../scripts/sonarr_trash_apply.sh)
- **Custom Formats**: Located in [scripts/trash_cf/](../scripts/trash_cf/) (`10bit`, `dual-audio`, etc.).
- **Quality Profile**: `Remux-1080p - Anime` (defined in [scripts/proposed_anime_profile.json](../scripts/proposed_anime_profile.json)).
- **Automation**: The script automatically:
  1. Creates/Updates Custom Formats in Sonarr.
  2. Creates/Updates the Quality Profile with specific CF scores.
  3. Assigns this profile to any series tagged as `anime`.
  4. Cleans up redundant profiles.

---

## 3. Maintenance

To apply changes or refresh the Sonarr configuration:

1. Update the JSON files in `scripts/trash_cf/`.
2. Run the dry-run script to verify:

   ```bash
   bash scripts/sonarr_trash_dryrun.sh
   ```

3. Apply the changes:

   ```bash
   RUN_SONARR_TRASH_APPLY=1 bash scripts/sonarr_trash_apply.sh
   ```

---

## 4. Future Improvements (TODO)

- **Radarr Integration**: Create `radarr_trash_apply.sh` and related CFs for 4K/1080p movies.
- **Auto-Sync**: Explore using a tool like [Recyclarr](https://recyclarr.dev/) or a script to pull the latest TRaSH scores directly from their GitHub.
- **Naming Schemes**: Sync TRaSH recommended [Naming Schemes](https://trash-guides.info/Sonarr/Sonarr-recommended-naming-scheme/) to ensure de-obfuscation and easier upgrades.
