# RECO-CLAUDE-MD-ARCHITECTURE.md

`/workflow:reco` report of 2026-09-26, for "Restructuring the global `CLAUDE.md` (opened on 2026-09-26)" in `PLAN-SESSION-DISCIPLINE.md`.
Input for the `/design` that followed it in a fresh conversation, `DESIGN-INSTRUCTION-ROUTING.md`.
It builds on `RECO-SESSION-DISCIPLINE.md` and does not repeat it.

Method: two subagents in parallel, one on official documentation and research papers, one on practitioners with Matt Pocock at the center.
Every URL below was refetched in the main thread (curl, `gh api`) and its key quote found with `rg -F` in the raw text; the Pocock quotes come from the raw files of `mattpocock/skills`.

## Local measurement (2026-09-26)

**The on-demand layer does not exist.**
`CLAUDE.md` presents five rules files as loaded on demand ("Load it on demand when...", "load `rules/pdf.md`"), none carries `paths:`, and all five arrived at startup in this session's context.
The always-loaded set is therefore about 121 KB, three times the file the question names: 41,056 bytes of `CLAUDE.md`, 54,331 for the five files and 25,571 for the memory index injected by `inject-project-context.sh`.
The pruning of `180a998` that reduced "PDF reading" and "DOCX verification" to a pointer saved nothing for those two topics, a pointer inside an always-loaded file displacing nothing.

**The regrowth vector is line lengthening inside mechanism commits.**
Since `180a998`, `CLAUDE.md` gained 1,751 bytes over 8 commits with 9 inserted and 9 deleted lines: no line was added, existing ones grew.
The three largest increments came from commits that added a mechanism and described it in the root file: `bcd7527` (`ending-gate.sh`, +579), `435a54c` (rename of `design`, English for Claude-facing content, +415), `f868c5b` (confirmed git writes, +371).
A line budget would have caught none of it.

## My take

Written before any agent result, not revised, as the skill prescribes.
It already held the ordered routing test, a byte budget enforced by a pre-commit check with "one in, one out", and headless replay before and after a move as the only thing counting as a test.
The sources refined it (a pointer needs a trigger, a moved rule needs a mechanical violation signal) and overturned none of it: one reading of the skill's uncontaminated-prior premise.

## Tradeoffs

- **Size against adherence.** On current models, the evidence that a longer file lowers adherence is weaker than every practitioner assumes (McMillan, below); the measured reasons to shrink are token cost, conflicts between rules, and staleness. Shrinking the file will not by itself fix a rule that keeps being violated; a hook will.
- **Pointer against always-loaded.** A pointer costs nothing but agents rarely follow it (Yang et al., below); an always-loaded rule is followed but paid on every turn. The middle path is injection at the triggering moment through `additionalContext` on `PreToolUse` or `UserPromptSubmit`, capped at 10,000 characters per hook output, so `docx.md` (12,023 bytes) does not fit whole.
- **`paths:` rules have blind spots.** They fire when Claude reads a matching file, so a PDF reached through `pdftotext` in Bash never triggers a `paths: **/*.pdf` rule; compaction summarizes them away; malformed frontmatter silently makes them always-on.
- **Budget gate against judgement.** A byte gate is nearly free and catches line lengthening, but its threshold has no evidence behind it and it invites denser writing. A periodic pass catches staleness but costs a session, and Pocock's own repository shows discipline plus review does not stop growth.
- **Testing cost.** The only official eval harness cannot load `CLAUDE.md` or user rules. A self-built `claude -p` A/B costs cases × reps × 2 agent runs and only works for rules with a mechanical violation signal.

## What the official documentation says

**Loading.** "Rules without [`paths` frontmatter](#path-specific-rules) are loaded at launch with the same priority as `.claude/CLAUDE.md`", where "Path-scoped rules trigger when Claude reads files matching the pattern, not on every tool use", and a frontmatter that does not parse means Claude Code "loads the rule as if it had no `paths`" (https://code.claude.com/docs/en/memory).

**(a) Criterion.** "**Use a hook** when the action must happen the same way every time and doesn't need Claude to think", an instruction such as "never edit `.env`" in CLAUDE.md or a skill being "a request, not a guarantee" (https://code.claude.com/docs/en/features-overview).

**(b) Regrowth.** A native gate exists, its thresholds unpublished: "If one of your instruction files is over the recommended length, you see a warning at startup and when you run `/status`. You also see a warning when files that are each within that length add up past a combined limit at session start" (memory page); on emphasis, "If you emphasize many lines, none of them stands out" (https://code.claude.com/docs/en/best-practices).
`/doctor` "proposes trims for a checked-in CLAUDE.md: it cuts content Claude can derive from the codebase" (memory page) and `/doctor prompt-audit` (changelog, v2.1.283, 2026-09-25) audits instruction files for patterns written for older models (https://code.claude.com/docs/en/changelog): whether either covers the user-level file, which is not checked in, is unverified, and both are worth one trial run on it.

**(c) Testing.** `claude plugin eval` can test a rule moved into a plugin skill or plugin hook, never one in `CLAUDE.md` or `~/.claude/rules`, its runs being isolated: "Your user settings, hooks, `CLAUDE.md` files, MCP servers, other installed plugins, memory, and skills are absent", and "There are no custom-code graders" (https://code.claude.com/docs/en/plugin-evals).
Headless mode is the documented building block: without `--bare`, `claude -p` loads the same context an interactive session would, "including anything configured in the working directory or `~/.claude`" (https://code.claude.com/docs/en/headless).

**Research (all 2026, Claude 4.x-era models unless stated).**
- McMillan, factorial study, 1,650 Claude Code CLI sessions, Sonnet 4.6 with Opus 4.6 and 4.7, files of 25 to 500 lines: "None of the four structural variables or three two-way interactions produces a detectable contrast", size and conflict nulls backed by Bayes factors 0.05 to 0.10; the largest effect is within-session decay, "(OR = 0.944)" per generated function. Limit: one trivial target instruction, not dozens of competing rules (https://arxiv.org/abs/2605.10039).
- Gloaguen et al., "Evaluating AGENTS.md", v2: "while instructions in the context files are well followed by coding agents, repository overviews, although popular and recommended by model providers, are not helpful", while "increasing inference cost by over 20% on average" (https://arxiv.org/abs/2602.11988).
- Yang et al., 106 issues, four frontier models including Sonnet 4.6: "today's agents almost never proactively retrieve the contribution rules", while reminder prompts, rule quotes and verifier feedback make agents pick up disclosure and verification; restraint rules (refuse, escalate) were never followed under any condition (https://arxiv.org/abs/2607.26819). The 3.5 % proactive-read rate and the 77 to 97 % lift are from the full text, checked by the agent only.
- Anand and Chattaraj, 1 to 20 stacked instructions, Sonnet 4.6 among others: "the follow rate falls from ~96% to as low as 20%", the collapse driven by pairwise conflicts rather than count (https://arxiv.org/abs/2608.02639).
- Khatri, Claude Code and Codex, 288 runs: context strategy "does not measurably move correctness" (https://arxiv.org/abs/2607.27250).

## What the community recommends

Pocock's position is taken from the raw files: "Never Run Claude /init" (https://www.aihero.dev/never-run-claude-init, 2026-02-24), the `retro` skill (`skills/in-progress/retro/SKILL.md`, created 2026-08-24, reworked 2026-09-15), `writing-for-agents` (`skills/productivity/writing-for-agents/SKILL.md` and `docs/productivity/writing-for-agents.md`), the AI Coding Dictionary entry (https://www.aihero.dev/ai-coding-dictionary/agents-md), and commit `4f6e25d9` of https://github.com/mattpocock/skills (2026-08-05).
Backing: M measured (method and n), A anecdote, O opinion.

```
| Point | Pocock | Others | Backing | Where the evidence points |
|---|---|---|---|---|
| Why keep it small | "every word costs on every turn" (4f6e25d9); instruction budget quoted as 150-200, then 300-400, then ~500 | Anthropic: longer files "reduce adherence"; HumanLayer 150-200; Arize re-run: ceiling near 2,000 on a keyword proxy | budgets O; McMillan M; ETH M | Cost, yes (ETH). Adherence collapse with size, not shown on current models (McMillan null, one instruction); conflicts do collapse it (Anand) |
| Pointers and progressive disclosure | "Branching is the cleanest disclosure test: inline what every branch needs, and push behind a pointer what only some branches reach" | Anthropic: skills load on demand; He et al.: one routing level is enough (long-document QA, other domain) | O; Yang M | Pointers alone fail (Yang, above); a reminder at the moment works |
| Mechanical rules | retro: a mechanical violation "gets a deterministic check" | Anthropic: hooks for "the same way every time"; HumanLayer: "Never send an LLM to do a linter's job"; Spence: skill activation 55 % without hook, 100 % with a forced-evaluation hook (n=22, Sonnet 4.5) | all agree; Spence M (small); Yang M (verifier feedback) | Unanimous and measured in the direction given |
| When a line is added | "When you've corrected the agent for the same thing twice, that correction is a candidate line for AGENTS.md" | Cherny: add a line whenever Claude does something wrong; HumanLayer (Kyle): add configuration "only when the agent actually failed" | O / A | No measurement. Pocock's twice-corrected bar is the only one that rate-limits growth |
| Stopping regrowth | per-commit shrink ("shrink the CLAUDE.md change to the pointer that earns it") plus retro as a periodic pass; no gate, no CI check | Anthropic: startup length warning and /doctor trim; superpowers: `WORD_BUDGET=1000` in `tests/diagnosing-superpowers/test-skill-structure.sh`; young linters (cclint warns at 10,000 characters) | all O | None measured. Pocock's root grew from 488 B to 3,737 B (`wc -c`, 24 commits) between 2026-04-28 and 2026-09-03 despite the discipline (n=1, but it is his own data) |
| Testing a moved rule | "There is no automated eval here; the check is a manual run" | superpowers: RED/GREEN pressure scenarios, a no-guidance control, 5+ reps per variant; Spence: `claude -p` in sandboxes | Pocock O; superpowers method; Spence M | Nobody has published adherence before and after a move from root to `paths:` or pointer: question (c) has no external answer |
```

**Where Pocock agrees with the field**: direction of routing (hooks for the mechanical, skills for procedures, a small root), and the cost argument.
**Where he diverges**: a stricter root criterion than Anthropic's (undiscoverable), a stricter admission bar than Cherny's (corrected twice), judgement rules sent to a file only the review agent reads (retro), and no testing or gating at all, where Anthropic and superpowers built both.
**What has evidence**: routing mechanical rules to hooks, the uselessness of derivable content, the failure of bare pointers, and the cost of always-loaded text. **What is opinion**: every size threshold, every instruction budget, and every regrowth mechanism.

## Final recommendation

Treat the whole always-loaded set (`CLAUDE.md`, unscoped rules, injected memory index, about 121 KB today) as one budgeted artifact: route each rule by its trigger, gate the sum in bytes with a prek check, and test moved rules only where a mechanical violation signal exists.

The shape it proposed for `/design` was approved on 2026-09-26 and is in `DESIGN-INSTRUCTION-ROUTING.md`, which carries each of the five files' destinations, the byte gate with the verifier check against the vector measured above, and the A/B restricted to the rules that leave a mechanical signal; the test itself is live in `rules/claude-files.md`, section "Where a new instruction goes".

Confidence: high on routing by trigger and on the unscoped-rules finding (documentation, this session's context and the file listing agree); medium on the byte gate and the verifier check, which no source has measured; low on size as a cause of non-compliance. The McMillan null makes "the size of `CLAUDE.md` is a named suspect of non-compliance" (Open points of the plan) a weak premise on Claude 4.6-era models: the restructuring is justified by cost, conflicts and staleness, and a violated rule is fixed by a hook, not by a shorter file. The memory index counts in the budget, but changing its injection stays with its own open point in the plan.
