---
name: feedback_answer_questions_dont_act_on_them
description: "Don't act on a question as if it were an instruction, and re-read the user's actual wording before answering — don't paraphrase-and-drift"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6a2492ec-73d4-4c44-8b0b-7ffd964705e6
  modified: 2026-08-15T01:28:28.008Z
---

Two related corrections from the same exchange (2026-08-15, Sonarr queue-cleanup discussion):

1. User asked "how should we make sure they don't stay in the queue forever?" — a request to explain the mechanism/options. Assistant went ahead and executed the cleanup (deleted 8 queue entries) without asking first. User: "ok I was asking you a question not asking you to fix it."

2. Follow-up: user asked "have [you] documented how to trigger an appropriate cleanup for scenario 1?" — asking whether documentation already exists. Assistant answered as if being asked to re-explain the mechanism again, missing that "documented" was the actual verb being asked about. User: "you have mis read what I said entirely."

**Why:** Bulk actions on shared state (queue entries, downloads, blocklists) need explicit go-ahead even when the fix seems obviously safe/correct — a question about *how* something works is not authorization to *do* it. Separately, when a message is short/direct, reread it literally before answering rather than pattern-matching to a similar-sounding prior question.

**How to apply:** When a user asks "how should we X" or "should we X", answer the question — don't perform X unless they say to. When re-reading a terse follow-up question, parse the actual verb/subject before drafting a response; don't assume it's a repeat of the previous turn's topic.
