# Auto Mode Classifier vs. Memory Files — Gap Analysis

## The problem

Memory rules that say "never do X" don't reliably stop the action, because
of a gap between what I (Claude) read and what auto mode's safety
classifier reads.

## How auto mode works (as of Claude Code v2.1.21x, Aug 2026)

Auto mode became the default for Pro/Max/Team plans on 2026-08-14. Instead
of prompting per tool call, a separate classifier model evaluates each
action before it runs and blocks anything irreversible, destructive, or
aimed outside the trusted environment.

Order of evaluation:
1. `permissions.deny` / `permissions.ask` — tool-pattern rules, evaluated
   *before* the classifier. Absolute; classifier never sees a denied call.
2. The classifier itself — prose-rule based, four tiers:
   - `hard_deny` — unconditional, can't be overridden by user intent or `allow`
   - `soft_deny` — blocks by default, but explicit user intent or an `allow` rule can clear it
   - `allow` — exceptions to `soft_deny`
   - explicit user intent — overrides remaining soft blocks if the user's message
     specifically names the exact action (a vague "clean up the repo" does not
     count as intent to force-push)

## The actual gap

**The classifier reads CLAUDE.md's literal text directly. It does NOT
follow file references inside CLAUDE.md.**

Our CLAUDE.md says "read `.claude/memory/MEMORY.md`" as an instruction to
me. I follow that instruction and load the file into my own context — but
the classifier never does. So any rule that lives only in
`.claude/memory/*.md` (not inlined into CLAUDE.md itself) is invisible to
the enforcement layer, even though I "know" it.

This is why a memory can say "never do X" and the action still happens: I
read the rule, but the thing that's supposed to independently block me
never saw it.

Rules already inlined as literal prose in CLAUDE.md (e.g. "NEVER use REST
API to update compose," "midclt REQUIRES sudo") *are* visible to the
classifier, since it reads CLAUDE.md text directly.

## Where classifier config actually lives

| Scope | File | Notes |
|---|---|---|
| CLAUDE.md | project root | Read directly by classifier — inline critical rules here |
| Personal | `~/.claude/settings.json` | `autoMode.hard_deny` / `soft_deny` / `allow` / `environment` |
| Org-wide | managed settings | same keys, distributed to all developers |
| Project | `.claude/settings.json` | **`autoMode` is explicitly ignored here** — prevents a repo from injecting its own classifier rules |

`.claude/settings.local.json` was also read by the classifier before
v2.1.207; that's no longer true — any `autoMode` block there should move to
`~/.claude/settings.json`.

`permissions.deny` / `permissions.ask` (a separate, non-`autoMode` settings
key) work in `.claude/settings.json` and are evaluated pre-classifier
regardless of scope — these are the strongest lever for a hard boundary.

## Two fixes, not mutually exclusive

1. **Inline critical memory rules into CLAUDE.md** — cheap, works today,
   but mixes "instructions for Claude" with "rules for the classifier"
   in one file.
2. **Add `autoMode.hard_deny` / `soft_deny` entries to
   `~/.claude/settings.json`** — prose rules the classifier enforces
   independent of what I read or do. `hard_deny` cannot be overridden by
   user intent; use it for the genuinely non-negotiable rules (e.g. no
   REST API compose updates, no `docker start/stop` on midclt-managed
   apps, no secrets in output).
3. **Use `permissions.deny`** for the very small set of things that must
   never even reach the classifier (tool-pattern based, not prose).

## Suggested next step (not yet done)

Audit `.claude/memory/*.md` for entries that are actually hard operational
rules (not preferences/context) and either:
- inline them into CLAUDE.md, or
- convert them into `autoMode.hard_deny` / `soft_deny` prose in
  `~/.claude/settings.json`

Candidates spotted so far (not yet verified against full memory index):
- no secrets in output (API keys, passwords, config file contents)
- TrueNAS native apps: never `docker start/stop`, only midclt
- never update compose via REST API — midclt stop→update→start only

## Useful commands for verifying classifier config

```bash
claude auto-mode defaults   # print built-in rule lists
claude auto-mode config     # print effective config (defaults + your settings)
claude auto-mode critique   # AI review of your custom rules for ambiguity/redundancy
claude auto-mode reset      # discard customizations, back to built-in defaults
```

## Sources
- https://claude.com/blog/auto-mode-default-in-claude-code
- https://code.claude.com/docs/en/auto-mode-config
