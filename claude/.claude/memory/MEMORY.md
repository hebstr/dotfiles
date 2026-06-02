# Memory Index

## User
- [user_profile.md](user_profile.md): Environment, accounts, and context not in CLAUDE.md
- [user_quarto_typst_only.md](user_quarto_typst_only.md): Quarto PDF via Typst only; user does not use LaTeX (do not suggest the `format: pdf` LaTeX path)

## Project
- [project_qmd_format_hook.md](project_qmd_format_hook.md): Add .qmd to PostToolUse format hook when air supports it
- [project_review_workflow_backlog.md](project_review_workflow_backlog.md): Implementation backlog from the 2026-03 code review glowup audit (hebstr tests, CI, data validation)
- [project_rv_install_deployment.md](project_rv_install_deployment.md): rv-install and quarto-update are stored in dotfiles but deployed on multi-user servers; affects threat model and portability (no amd64 assumption)
- [litrev-separate-from-hebstr.md](litrev-separate-from-hebstr.md): Decision (2026-04-26): keep litrev separate from hebstr marketplace; do not re-propose merge

## Reference
- [reference_editorconfig.md](reference_editorconfig.md): EditorConfig for team/multi-editor formatting consistency
- [reference_claude_hooks.md](reference_claude_hooks.md): Claude Code harness event types, hook kinds, and MCP rejection rationale (2026-03-26)
- [reference_claude_code_best_practices.md](reference_claude_code_best_practices.md): Claude Code internals: CLAUDE.md scopes, hook events, auto-memory, notable settings.json keys (2026-05-02)
- [reference_todo_sync.md](reference_todo_sync.md): `todo-sync` shell command prints aggregated TODO.md items to stdout as a markdown table
- [claude-code-marketplace-mechanics.md](claude-code-marketplace-mechanics.md): Marketplace + plugin lifecycle; cache vs live edits for directory-source plugins

## Feedback
- [feedback_verify_before_claiming.md](feedback_verify_before_claiming.md): 6 hard rules for verifying factual claims; detail behind the CLAUDE.md rule "never state a verifiable fact without checking it first"
- [feedback_review_workflow.md](feedback_review_workflow.md): Preferred review workflow: 3 background specialists + 2-3 foreground agents by facet, consolidated report, then `/audit:walkthrough`
- [feedback_review_severity_personal.md](feedback_review_severity_personal.md): Calibrate review severity down for personal/internal packages
- [feedback_review_severity_shell_installers.md](feedback_review_severity_shell_installers.md): Calibrate review severity for personal shell installers (quarto-update, positron-update, etc.)
- [feedback_review_severity_bats_tests.md](feedback_review_severity_bats_tests.md): Calibrate review severity for bats `.bats` test files covering personal shell tooling
- [feedback_review_severity_claude_rules.md](feedback_review_severity_claude_rules.md): Calibrate review of `.claude/rules/` files: skip duplication-from-CLAUDE.md, dedup-of-boilerplate, version-trace headers, review-calibration-as-writing-rule, alternate-tool-removal-due-to-overlap (5 recurring false positives)
- [feedback_review_severity_claude_config.md](feedback_review_severity_claude_config.md): Calibrate `/health` and audits of `~/.claude` harness config (settings.json, hooks): skip PWD-guard expansion, rg-in-hook-scripts, message-aware notifications, WebFetch allow-list expansion, race-condition hardening on best-effort cleanup hooks (5 recurring false positives)
- [feedback_review_severity_claude_md_content.md](feedback_review_severity_claude_md_content.md): Calibrate content audits of CLAUDE.md instructions: skip under-defined-term-with-anchored-criteria, opt-out-against-user-preference, trigger-owned-upstream, deliberate-bias-catching-cost, harness-backstopped-efficiency-hint, length-offload-as-walking-fix (6 recurring false positives)
- [feedback_claude_md_refactor.md](feedback_claude_md_refactor.md): CLAUDE.md Progressive Disclosure refactor: do not extract always-on safety-net checklists (silent-failure), do not automate via hook what prose pointers already cover (2 recurring false positives)
- [feedback_review_severity_skill_audits.md](feedback_review_severity_skill_audits.md): Calibrate skill-adversary/blindspot/sweep on SKILL.md files: skip harness portability, declared-prior anchoring, CLAUDE.md duplication, explicit-invocation FN concerns (4 recurring false positives)
- [feedback_explicit_invocation_gate.md](feedback_explicit_invocation_gate.md): Explicit-only invocation gate for hebstr/claude-code-plugins skills; reject reviewer trigger-breadth findings
- [feedback_review_severity_litrev_mcp.md](feedback_review_severity_litrev_mcp.md): Calibrate adversarial audits on litrev-mcp (FastMCP server): in-memory pipeline ≠ file mutation, reactive env-tips are idiomatic FastMCP, empty-string is the schema sentinel (3 recurring false positives, blindspot 2026-05-17)
- [feedback_litrev_pipeline_patterns.md](feedback_litrev_pipeline_patterns.md): Recurring `/litrev` scoping decisions: post-hoc restrict above 150 incl., skip backward snowball with recent window, audit_claims/synthesize DOI conflict, bypass validate_gate stall, strip pseudo-GRADE, two-pass post-gen prose cleanup (6 rules, epidemio PRISE 2026-05-17/18)
- [feedback_walkthrough_process.md](feedback_walkthrough_process.md): Interactive walkthrough: point-by-point, terse, inline corrections, recap at end
- [feedback_verify_quarto_theming.md](feedback_verify_quarto_theming.md): Quarto theming: always render and scan compiled CSS to verify SCSS changes land and win specificity
- [feedback_french_prose.md](feedback_french_prose.md): FR prose: authorities, anglicism policy, typography, register: full reference for prose work
- [feedback_review_third_party_content.md](feedback_review_third_party_content.md): Don't apply CLAUDE.md prose style rules to third-party skill descriptions, plugin docs, or forked content
- [feedback_external_pattern_imports.md](feedback_external_pattern_imports.md): Filter for external Claude Code config imports: identify the consumer that justifies the format before importing (4 false positives in solatis audit 2026-05-16)
- [feedback_verify_after_install.md](feedback_verify_after_install.md): Smoke-test new tools/hooks/integrations end-to-end before marking done; never suppress stderr on fresh config
- [feedback_shell_grep_pipefail.md](feedback_shell_grep_pipefail.md): `grep` as filter under `set -Eeuo pipefail` crashes on no-match; idiomatic fixes + audit grep
- [feedback_prose-lint-write.md](feedback_prose-lint-write.md): typographic vs rhetorical em/en dash distinction in prose-lint scope, when to invoke /workflow:write, and never replace typographic glyphs with words
- [feedback-no-bulk-regex-for-contextual-skills.md](feedback-no-bulk-regex-for-contextual-skills.md): Don't substitute a contextual editing skill (workflow:write, audit reviewers) with a bulk regex when per-case Edit is blocked; surface the blocker instead
- [feedback_edit_proposal_format.md](feedback_edit_proposal_format.md): Propose edits via the Edit tool directly; don't duplicate diffs as prose before/after blocks in chat
- [feedback_audit_walkthrough.md](feedback_audit_walkthrough.md): audit:walkthrough triage table format; lenient severity for personal scripts (locale/portability)
- [feedback_checkup_scope.md](feedback_checkup_scope.md): "audit complet du répertoire" = scan ALL files in CWD, not just the active file
- [feedback_ouroboros_tools.md](feedback_ouroboros_tools.md): Only `ouroboros_evaluate` supports `trigger_consensus`; `ouroboros_qa` silently ignores it
- [feedback_skill_adversary_sync.md](feedback_skill_adversary_sync.md): skill-adversary on workflow:sync: 7 false-positive patterns to pre-filter
- [feedback_xdg_open.md](feedback_xdg_open.md): xdg-open silently fails on file:// in Positron/VSCode; use `python3 -m http.server` for HTML preview
