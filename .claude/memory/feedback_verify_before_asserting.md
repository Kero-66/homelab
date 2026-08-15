---
name: feedback_verify_before_asserting
description: Check actual data before stating explanations as fact, especially about show/indexer metadata
metadata:
  type: feedback
---

Don't state an explanation as fact before checking the data that would confirm or refute it — even when it sounds plausible or matches general knowledge.

**Why:** During the missing-episodes investigation (2026-08-07), stated two wrong things as fact in a row without checking first: (1) that Robotech's episode-numbering gap was due to its well-known Western-compilation production history — user corrected this outright ("robotech is just robotech"); (2) that "every enabled indexer is anime/fansub-focused" based on indexer names/descriptions — disproven immediately when the user asked how 36 episodes were already downloaded, and checking history showed SceneNZB had grabbed a standard Western scene release. Both were plausible-sounding theories built on partial evidence or general knowledge, asserted before verifying against the actual system state.

**How to apply:** Before offering an explanation for *why* something is failing/missing/behaving a certain way, check the concrete data first (query history, check config, look at actual results) rather than reasoning from general knowledge or indexer names/labels. If short on time, frame it explicitly as an unverified hypothesis ("possibly because X — want me to check?") rather than a stated conclusion. Related: [[feedback_trash_guides_primary_source]] — same underlying pattern of not checking primary sources before asserting.
