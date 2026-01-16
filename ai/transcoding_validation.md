# Transcoding Validation Plan

To ensure we maintain video quality while saving space and avoiding the "Arr Loop", we are using a **Sandbox Validation** approach.

## 1. Test Environment

- **Tool**: FileFlows (Modern, visual, AMD GPU supported)
- **Host hardware**: AMD Ryzen 9800X3D + Radeon 9070 XT
- **Test Folder**: `/mnt/wd_media/homelab-data/transcode_test/`
- **Current Test File**: `test_remux.mkv` (24.3GB Anime Remux - Copy Verified)

## 2. Validation Steps

1. **GPU Verification**:
   - Status: Detected. Logs show `AMD Device 7550 (Navi 48)`.
2. **Setup Library**:
   - Status: Configured with `Wait/Hold` safety settings.
3. **Configure the "Transcode Flow"**:
   - Settings: HEVC (VAAPI), Quality: High (CRF 20), Audio/Sub: Pass-through.
4. **Compare & Verify**:
   - **Quality Check**: Play the original vs. the transcode in Jellyfin.
   - **Space Check**: Calculate saved percentage.
   - **Arr Loop Check**: Update Radarr library and verify it doesn't trigger a redownload.

## 3. Success Criteria

- [ ] No perceptible loss in video quality on target display.
- [ ] At least 40% reduction in file size for 1080p Remuxes.
- [ ] Radarr sees the new file as a "Remux" and marks it "Downloaded".
