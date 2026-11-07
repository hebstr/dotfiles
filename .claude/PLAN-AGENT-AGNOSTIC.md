# Opening the harness to agents other than Claude Code

Direction stated by the user on 2026-11-05, in their own words still vague: progressively emancipate the harness from Claude-specific features and move toward something more generalisable, flexible and agent-agnostic, keeping the same harness and the same quality, while continuing to use Claude Code alongside. **An opening and not a replacement.**
This note exists so the direction is on paper before the decisions that would ignore it, and it records no decision of its own: nothing here is settled.

## Why it is written now

A reco chantier on agent-facing note management opened the same day. Left without this direction it would recommend what is right for Claude Code and nothing elsewhere: a `paths:`-scoped rules file, a `SessionStart` hook, a skill. So the reco was asked to qualify each recommendation as portable or Claude-specific, and to price the portable form where the two diverge.

It was delivered on 2026-11-06 as `~/dotfiles/_meta/notes/agent-notes-discipline-reco.md`, and it came out favouring the portable surface on both axes, keeping the Claude-specific mechanisms for the one capability the portable stack lacks: firing deterministically at write time with the reason handed back to the agent. So the alignment this note sequences after it is the cheap case rather than a translation. The `/design` that takes the reco as input is where any change to an instruction file is decided.

The design ran and was approved the same day (`.claude/DESIGN-INSTRUCTION-ROUTING.md` § "The hook owns `claude-files.md`, a write-time cap replaces dropping the `PLAN.md` mandate, and the shape ban narrows to the copula form"), and its three changes do not all pull the same way.
The write-time gate landed on `bin/.local/bin/prose-lint` driven by `prose-lint-pretool.sh`, which `opencode/.config/opencode/plugins/claude-hooks.ts` already forwards and whose exit 2 it already turns into a refused edit, so the one vendor-locked capability arrives on an instrument both harnesses run.
The other two are Claude-only, and the first moves `rules/claude-files.md` off the `paths:` layer, which has equivalents in Cursor, Windsurf, Devin and Copilot, onto the hook layer, which has none.
So the direction is served where the reco said it would be and traded against a token saving elsewhere, which is the first concrete price this note exists to keep visible.

## The two facts that bear on it, measured 2026-11-05

**The note discipline is on the Claude-only side of the line by explicit decision.** `DESIGN-OPENCODE-HARNESS.md` § « `AGENTS.md` keeps what any agent can apply, 2026-09-21 » lists what was kept out of `AGENTS.md`, opening on "memory and `PLAN.md` discipline" and "skills and hooks". That is the reco's own subject, so aligning the two instruction files means carrying across the discipline the reco is about to redesign. Hence the order: the reco first, the alignment after, because a discipline that comes out portable by construction makes the alignment cheap where one that does not makes it a translation.

**Half the basis of the rejection that blocks full alignment has moved.** That same section rejected "carrying every agent-agnostic rule (about 8 KB)" on two premises: adherence dropping as instructions accumulate, "more so on small models", and a larger copy drifting faster from `CLAUDE.md`. `opencode.json` now declares `cpd/qwen3.8-27b` as its default model, on the remote host, with `qwen3.5-9b` as a second entry. The small-model premise has therefore moved; the drift premise has not, and memory `project_opencode_agents_md_mirror` records that no mechanism keeps the two files in sync and that the user accepted that risk by hand. Re-deciding the 8 KB rejection is a separate pass and is not opened here.

## The chantier the user names for a second step

Reformatting `~/Documents/packages/claude-code-plugins` into a collection of skills usable by any agent, renamed `hebstr-agent-skills` in their own words.
Measured 2026-11-05: the repository carries two plugin directories, `audit/` and `workflow/`, seven `SKILL.md` in all, and one `.claude-plugin/marketplace.json`. Claude-specific couplings per skill, counted on `allowed-tools`, `disable-model-invocation`, `CLAUDE_PLUGIN_ROOT` and `claude-code`: eleven in `audit/blindspot`, five in `audit/sweep`, four in `workflow/sync`, two in each of the other four. So the coupling is real and bounded rather than structural.
Two things such a pass would have to settle, flagged and not solved: `disable-model-invocation` has no equivalent outside Claude Code, and it is what keeps a user-invocable skill from auto-firing, which several of these depend on; and a rename touches the install side, the marketplace manifest and whatever `extraKnownMarketplaces` entry points at it (memory `reference_claude_code_marketplace_mechanics`).

## What stays open

Whether the direction becomes a chantier at all, and when.
Whether `AGENTS.md` moves from a hand-picked digest toward an aligned copy, which is the 8 KB rejection above re-decided on its moved premise.
What "the same quality" means operationally for an agent without subagents, without hooks and without a skill gate, which is the question underneath the whole direction and which nothing here answers.
