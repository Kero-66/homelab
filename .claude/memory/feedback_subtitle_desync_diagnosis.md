---
name: feedback_subtitle_desync_diagnosis
description: Diagnosing subtitle sync/missing-text reports — what actually worked on Oshi no Ko S01E07 after many wrong turns
metadata:
  type: feedback
---

A "subtitles are wrong" report can have a completely different root cause than subtitle *timing*. On Oshi no Ko S01E07, the real bugs (in order encountered) were: (1) Bazarr's audio-resync defaulted to the wrong audio track reference (English dub, not the Japanese track being played) — but even after fixing the reference, (2) the client wasn't using the file being edited at all (defaulted to a different embedded subtitle track), and finally, after replacing the whole release, (3) Sonarr's auto-extracted `.en.cc.srt` only pulled "Caption"/"Song" ASS styles and silently dropped the "Subtitle" style — i.e. it exported signs/lyrics but not a single line of spoken dialogue. None of these were timing bugs; #3 in particular had nothing to do with sync at all despite presenting as "subtitles not showing."

**Why this took so long:** I spent a lot of effort on audio-waveform silence-detection heuristics (noisy, inconclusive, contradicted itself) before realizing the release's own embedded ASS track was a far better ground truth than reconstructing timing from raw audio. I also didn't check early enough which subtitle *stream index* the client was actually using (`sudo docker logs jellyfin | grep '<filename>'` for `DirectPlay Result`/`Transcode Result` lines shows the real `AudioStreamIndex`/`SubtitleStreamIndex` per session) — I assumed the file I was editing was the one being played. When a new release still had "missing" subtitles, I assumed it was another sync issue and almost went back to timing analysis — the actual bug was a completely different failure mode (extraction dropped a whole ASS style/track), caught by comparing the extracted SRT's cue count against the full embedded ASS's dialogue-style cue count (93 vs 330 — an order-of-magnitude gap is a strong sign of missing content, not misalignment).

**How to apply, in order, for any "subtitles are wrong" report:**
1. Check server logs for which subtitle *stream index* was actually used in the real session (`docker logs jellyfin`, grep the filename, look for `DirectPlay Result`/`Transcode Result`) — confirm you're even looking at the right file before touching timing.
2. If content seems to be missing/blank for stretches, extract the full embedded subtitle track (`ffmpeg -map 0:<idx> -f ass -`) and diff cue counts per `Style:` against whatever external file is being served — a large gap points to a bad extraction, not desync.
3. Only reach for audio-based sync tools (Bazarr resync, silence-detection) once content-completeness is confirmed — and when doing so, always match the audio *reference track* to the audio track actually being played (see the `reference=a:N` param in `ai/PATTERNS.md` Bazarr section).
4. If multiple independent, mutually-consistent subtitle sources are all reported wrong across multiple unrelated clients, stop tuning the file — the file's timing data is probably not the bug.
5. When genuinely stuck after real diagnosis, replacing the release entirely via Sonarr (interactive release search, force manual import if the quality profile blocks it) is a legitimate, fast reset — don't be afraid to abandon a specific troublesome encode.
