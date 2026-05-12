# Memory Index

## User
- [user_profile.md](user_profile.md) — Environment, accounts, and context not in CLAUDE.md

## Project
- [project_qmd_format_hook.md](project_qmd_format_hook.md) — Add .qmd to PostToolUse format hook when air supports it
- [project_review_workflow_backlog.md](project_review_workflow_backlog.md) — Practices and backlog items from the 2026-03 code review glowup audit

## Reference
- [reference_editorconfig.md](reference_editorconfig.md) — EditorConfig for team/multi-editor formatting consistency
- [reference_claude_hooks.md](reference_claude_hooks.md) — Claude Code harness event types, hook kinds, and MCP rejection rationale (2026-03-26)
- [reference_claude_code_best_practices.md](reference_claude_code_best_practices.md) — Claude Code internals: CLAUDE.md scopes, hook events, auto-memory, notable settings.json keys (2026-05-02)

## Feedback
- [feedback_verify_before_claiming.md](feedback_verify_before_claiming.md) — 6 hard rules for verifying factual claims; detail behind the CLAUDE.md rule "never state a verifiable fact without checking it first"
- [feedback_review_workflow.md](feedback_review_workflow.md) — Preferred review workflow: 3 background specialists + parallel-review + consolidated report + walkthrough
- [feedback_review_severity_personal.md](feedback_review_severity_personal.md) — Calibrate review severity down for personal/internal packages
- [feedback_review_severity_shell_installers.md](feedback_review_severity_shell_installers.md) — Calibrate review severity for personal shell installers (quarto-update, positron-update, etc.)
- [feedback_review_severity_bats_tests.md](feedback_review_severity_bats_tests.md) — Calibrate review severity for bats `.bats` test files covering personal shell tooling
- [feedback_review_severity_claude_rules.md](feedback_review_severity_claude_rules.md) — Calibrate review of `.claude/rules/` files: skip duplication-from-CLAUDE.md, dedup-of-boilerplate, version-trace headers, review-calibration-as-writing-rule (4 recurring false positives)
- [feedback_review_severity_skill_audits.md](feedback_review_severity_skill_audits.md) — Calibrate skill-adversary/blindspot/sweep on SKILL.md files: skip harness portability, declared-prior anchoring, CLAUDE.md duplication, explicit-invocation FN concerns (4 recurring false positives)
- [feedback_walkthrough_process.md](feedback_walkthrough_process.md) — Interactive walkthrough: point-by-point, terse, inline corrections, recap at end
- [feedback_verify_quarto_theming.md](feedback_verify_quarto_theming.md) — Quarto theming: always render and scan compiled CSS to verify SCSS changes land and win specificity
- [feedback_french_prose.md](feedback_french_prose.md) — FR prose: authorities, anglicism policy, typography, register — full reference for prose work
- [feedback_review_third_party_content.md](feedback_review_third_party_content.md) — Don't apply CLAUDE.md prose style rules to third-party skill descriptions, plugin docs, or forked content
- [feedback_verify_after_install.md](feedback_verify_after_install.md) — Smoke-test new tools/hooks/integrations end-to-end before marking done; never suppress stderr on fresh config
- [feedback_shell_grep_pipefail.md](feedback_shell_grep_pipefail.md) — `grep` as filter under `set -Eeuo pipefail` crashes on no-match; idiomatic fixes + audit grep
