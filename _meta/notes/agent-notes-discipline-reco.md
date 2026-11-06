# Agent-facing notes: structure, startup payload, and routine maintenance

2026-11-06.
Decision asked: how the agent-facing corpus of this harness should be structured and maintained so a session's startup payload stays small, whether tooling exists to pilot it, and which of the conventions in force are dated or counterproductive.

Verdict: this is not primarily a size problem.
Make the always-loaded surface a generated bounded index, put one loud-failing gate at write time on the single machine-decidable shape, and drop the mandate that `PLAN.md` be read whole at session start.
Keep the routing test, the subtractive criterion and the re-derivation criterion as written.

Scope: the harness globally, not one project.
Out of scope and deferred to a `/design`: which file becomes what, and how any routine is implemented here.
Installing any tool named below is a separate `/poc`.

## Two premises of the chantier were wrong, and both are good news

`.claude/rules/` with `paths:` front matter is a shipped, documented Claude Code feature, not an emulation of one.
`paths` is the only field Claude Code reads from a rule, and a rule without it loads at launch with the same priority as `.claude/CLAUDE.md`.

The memory store is the native auto-memory feature, relocated: `settings.json` sets `autoMemoryDirectory` to `~/.claude/memory`.
So the vendor's caps apply to it directly, and the four `type` values in use are the documented set.

The harness is therefore already built on the documented shape rather than beside it.
That changes the design question from "invent a discipline" to "stop fighting the one that ships".

## Mechanism caps that bind any design

Verified against `code.claude.com/docs/en/*` on 2026-11-06, on 2.1.319.
The old `docs.claude.com/en/docs/claude-code/*` paths now redirect there.

A hook's `additionalContext` and plain stdout are capped at 10 000 characters.
Above it the output is written to a file and replaced by the path plus a 2 000-character preview, and Claude is never asked to read the file.
A digest replacing the `PLAN.md` read has that hard ceiling and fails silently past it.

`@path` imports do not reduce context cost: imported files load together with the file importing them.

A path-scoped rule is summarised away by compaction and returns only when a matching file is touched again.
Anything that must survive compaction belongs in the project-root `CLAUDE.md` or in an unscoped rule, both re-injected from disk.

A malformed `paths:` YAML block makes the rule load unconditionally, with no error.
`claude --debug` surfaces the parse error.

A plan written in plan mode is disk-backed and re-injected from disk after every compaction.
A hand-written `.claude/PLAN.md` gets none of that.

Editing a launch-loaded `CLAUDE.md` mid-session does not apply until `/clear`, `/compact` or a restart.
Editing a not-yet-loaded nested file or path-scoped rule does apply.

Published ceilings: 200 lines per `CLAUDE.md` with a startup and `/status` warning, a combined-file limit whose value is not published, 4 MiB hard skip, 40 000 characters per on-demand file on a 200K window, 200 lines or 25 KB for `MEMORY.md`, 500 lines for a `SKILL.md`.
The skill listing budget is 1% of the context window, and over it Claude Code drops descriptions starting with the least-invoked skills.

`InstructionsLoaded` is observability only and cannot act.
It is already wired here to `instructions-log.sh`, which is what made the measurements below possible.

## Why the 200-line target under-reports here

The no-soft-wrap convention puts one sentence on one line, so line counts stop tracking size.
Re-derive with `wc -lc` over the launch-loaded files: two of them sit under the 200-line target while being among the largest in the corpus by bytes.
The startup warning fires off lines, so it stays silent on them.

Consequence for the design: measure this corpus in bytes or tokens, never in lines.
The same defect sinks the 500-line `SKILL.md` heuristic, which `heydamir/unslop` demonstrates at 134 bytes per line.

## The size axis and the accuracy axis call for different moves

Size costs money and nothing else that anyone has reproduced.
Gloaguen et al. measure context files adding over 20% inference cost without generally improving task success.
McMillan's factorial over 1 650 Claude Code sessions finds affirmative Bayesian evidence of no size effect on adherence (BF10 between 0.05 and 0.10 for the size null).
Anthropic's own shipped prompt-audit says "Cruft != length" and "Never justify a deletion by character count alone", which contradicts the memory page's claim that longer files reduce adherence.
Divergence named, not resolved: do not lead a remedy with size.

A false fact costs a wrong decision instead, and the content class that rots is the class measured useless.
Gloaguen et al. again: instructions are well followed, while repository overviews are not helpful and did not even reduce the steps an agent took to reach the file the PR changed.

Deletion alone does not hold.
Chakrabarti measures +226% growth over an instruction file's lifetime and +4.9 net instructions per commit across 247 694 instruction lifetimes, with the deletion hazard falling as an instruction ages.
From that paper's full text, not its abstract, so one tier lower: wholesale rewrites carry 76.8% of instruction deaths, the file returns to 91.5% of its pre-rewrite size within 10 commits, and then grows faster than before.
The 33-day regrowth measured in `eds-prise` is the predicted outcome of a prune with no gate behind it.

## The criterion in force is confirmed

A figure enters a note only if a named command re-derives it in seconds, in which case the command is written and never its output.
Otherwise it is deleted, not dated.

That is the field's rule with a cost test attached, stated in the most-adopted practitioner artefact (`mattpocock/skills`, `skills/productivity/writing-for-agents/SKILL.md`): a document that restates the environment "is a **cache**: a copy of a lookup, earning its load only when the lookup is expensive", so "Leave the one-file, one-command lookups to the environment, where they cannot go stale".
The same file names the growth mechanism: "**sediment**: stale layers that settle because adding feels safe and removing feels risky".

Dating stays reserved for a figure whose evidence was destroyed and which still binds a decision.
`R-edstr`'s dated, rule-compliant and unusable test count is the case that proves dating saves nothing when the unit is wrong.

## Why three written rules failed, and what fires at write time

The rules failed because they are prohibition prose, which is the worst available instrument.
In the only A/B found on instruction wording (`obra/superpowers`), the prohibition arm produced more of the unwanted content than the recipe arm and trended worse than no guidance at all.
Matt Pocock states the same lever independently: steering by prohibition drags the forbidden behaviour into context. Prompt the positive.

One variable predicts whether a maintenance mechanism survives: whether it fails loudly when the artefact goes stale.
Three write-time shapes pass that test.

1. Generate the number instead of writing it.
   `cog` with `--check` in a pre-commit gate, verified live in `pypa/cibuildwheel` (`cog -c -P -r -I ./bin README.md`, `cogapp>=3.5`), whose generated regions carry checksums so a hand edit inside one is caught.
   Four adopters have carried the hook continuously since 2023.
   A generated count cannot be stale.
   Portable.

2. The two-tier count gate, the closest fit to the defect measured here.
   `cathrynlavery/diagram-design` ships `scripts/verify-docs-sync.py`, run in CI and itself tested, which excludes its agent-facing surfaces from count verification and requires them to be count-free, while reader-facing surfaces may state a count and must match.
   Read `COUNT_SURFACES` and `VERIFIED_COUNT_SURFACES` in that file for the split, and its two error messages for the rule in executable form.
   Portable: plain Python plus CI.

3. Ban the shape, not the fact.
   This inverts the 86%-false-positive measurement rather than contradicting it.
   No regex can decide whether a stated count is still true, which is why the detector failed.
   A regex decides trivially whether a sentence asserts a repository count at all.
   Deletion removes the occurrences once; a shape ban removes the next one.
   The vendor already ships this architecture for exactly two shapes: a memory write whose content looks like a credential is refused at write time with a corrective message to the writer.
   Claude-specific as a `PreToolUse` deny on `Write|Edit`; portable as a Vale `existence` check at `level: error`.

Caution on noise, from Vale's own agent hook header: surfacing advisory findings on every edit is how people turn a linter off.
Errors only.

## The plan-versus-design split

The split is right and the placement is wrong.
The field keeps a session-start state artefact but bounds it, and what survives is one file per unit of record plus a generated index.
`jbranchaud/til` has run 11.7 years and `simonw/til` 6.5, both with machine-built indexes and CI checks.
Nobody reports sustaining a single growing document.

The rule the plan is missing comes from OpenSpec, which ships `archive` as a first-class command: the record of what actually happened is not the source of truth for current intent.
That is the retention rule of 2026-11-05 generalised, and it names the regrowth shape precisely: transcribing an outcome into the plan when the reasoning lives in a sibling design note is duplication, which both governing conventions forbid.

ADRs are not the alternative.
Half the repositories that have ADRs have one to five, `adr-tools` and `log4brains` are both dormant, and no agent-era ADR corpus is old enough to assess before 2027.

## Tooling: what exists, what does not

Structural checks exist and are live.
`zk` is the best fit for a flat cross-referenced note store: `--orphan` returns notes with no links pointing to them, `--broken-links` returns notes with at least one broken outgoing link, and its LSP `dead-link` diagnostic defaults to `error` while the three advisory ones default to `none`.
It needs no application running and works on a dot-prefixed directory.
Also live: `lychee`, `markdownlint-cli2`, Vale.

Dead or disqualified: Dendron (halted by its maintainer), Logseq for a markdown corpus (feature-frozen by its own 2026-04 split), Quartz (no tagged release since 2023).
Obsidian excludes dot-prefixed folders and needs the app running, and the plugins working around that are marginal.

Clean negative: size and growth dashboards for a markdown corpus are not a category.
`markdownlint` has no length rule at all.
The only right-shaped instrument for "did the pruning hold", `git-of-theseus` survival curves, is dormant since 2023 with no releases.
Instruction-drift linters are a graveyard of five-day repositories.

No tool anywhere checks a prose number against a measurement.
The checks that work are structural: a link resolves, a named file exists, a generated region matches regeneration.

Do not add a retrieval layer over the note corpus.
Grep and direct corpus interaction beat vector retrieval in coding harnesses.
Letta's server is retired, Zep's self-hosted path was deleted, cipher is archived, graphiti has independently reproduced silent data loss, and `basic-memory` writes into frontmatter with the opt-out removed, which is a hazard for a Syncthing-synced store whose memory files carry hand-maintained frontmatter.

## Verdicts on the conventions in force

```
| Convention | Verdict | Axis served |
|---|---|---|
| Routing test | Keep. Vendor states it bidirectionally, and the prohibition A/B strengthens it | both |
| Subtractive criterion | Keep, paired with a gate. Deletion alone regrows | size |
| Figure only if a command re-derives it | Confirmed. It is the field's cache rule with the cost test | accuracy |
| `PLAN.md` state / `DESIGN-*.md` reasoning | Keep the split, move the placement, add the current-intent rule | size |
| `PLAN.md` read whole at session start | Drop the mandate. The one convention the field has unanimously moved past, and no public repository implements a session-start hook loading a plan file | size |
| No comments in code | Keep, on the corruption asymmetry rather than the usual argument. Removal is near-null for frontier models, while corrupted or outdated comments cost 21% to 29% (CodeCrash, NeurIPS 2025) and up to 58% more defects (FSE 2026), with instructions to ignore them barely helping | accuracy |
| English for agent-facing content | Keep as a maintenance rule, drop any performance claim. French is at parity on every current frontier model, and the one direct system-prompt-language ablation found English marginally worse while still recommending it for maintenance | neither |
```

## Open question the evidence does not settle

Routing a WHY out of the code and into a note has never been tested against keeping it inline, in either direction.
The one paper that halted instruction growth did it by attaching the rationale next to the instruction and states that inline-ness is constitutive of the effect.
So "the WHY is safe because it lives in a tracking note" is an assumption, not a finding, and the no-comments rule rests on the corruption asymmetry instead.

## Portable or Claude-specific

Portable and now institutionally governed: `AGENTS.md`, and `SKILL.md` with `references/`, `scripts/`, `assets/` under the agentskills.io specification, whose `GOVERNANCE.md` was adopted 2026-11-04 under LF Projects with budgets of about 100 metadata tokens, under 5 000 body tokens, 500 lines, and references one level deep.
`references/` is documented there and never named on the Claude Code skills page.

Portable practices: a generated CI-checked index, one file per record, archive rather than delete, `cog` with `--check`, a CI gate recomputing a documented count, Vale `existence` at error level, `zk`, `lychee`, `prek`, procedure instead of number.

Claude-specific: every hook event, path-scoped `.claude/rules/`, auto memory's caps and its write-time rejections, `claudeMdExcludes`, `/doctor prompt-audit`, `/context`, `/usage`, plugins.

Path-scoped instruction loading has an equivalent in Cursor (`globs`), Windsurf and Devin (`trigger: glob`) and Copilot (`applyTo`, GitHub.com surfaces only), and none in Codex, Gemini CLI, opencode or Zed.

Pricing: the measured evidence favours the portable surface on both axes.
In the only published head-to-head an `AGENTS.md` docs index scored 100% against a skill's 53%, with the skill never invoked in 56% of cases.
The portable gate stack is alive across every tool checked, over spans up to 12 years, against most visible Claude Code hook repositories being dead and unarchived.
The Claude-specific mechanisms earn their keep for one capability the portable stack lacks: firing deterministically at write time, inside the session, with the reason handed back to the agent.
That is the capability the accuracy defect needs, and it is the one worth keeping vendor-locked.

## Measured on this machine, 2026-11-06, for the design to act on

These are dated measurements, not live claims. Re-derive before acting.

`claude-files.md` was delivered twice in 507 of 854 logged sessions, once by the shipped `paths:` mechanism and once by `inject-rules.sh`, at roughly 1 783 tokens each time.
Re-derive from `$XDG_STATE_HOME/claude-code/instructions.log` by intersecting `path_glob_match` and `inject` events per session.
The rules carrying self-referential `paths:` globs do not collide, because that glob exists to hand the trigger to the hook, which fires on tool class where the shipped mechanism cannot.
The rules carrying real globs do collide.

No rules file had loaded at session start in the preceding seven days, so the claim that none is unconditionally loaded holds empirically.
The five that appear with `session_start` in the log all date from 2026-09-26, before they were scoped.

The skill listing is already over budget: two skills arrive in a session with no description at all while carrying roughly 950 characters each on disk.
Re-derive the listing demand by summing `name`, `description` and `when_to_use` across discoverable `SKILL.md` files, and compare against 1% of the context window.
This is a correctness cost of corpus size rather than a token cost, since dropping a description removes the keywords the model matches on.
Knobs: `skillListingBudgetFraction`, `SLASH_COMMAND_TOOL_CHAR_BUDGET`, `skillListingMaxDescChars`, `skillOverrides` set to `name-only`, `disable-model-invocation`.
Diagnostics: `/doctor`, `/skill-doctor`, the Skills row in `/context`.

`MEMORY.md` sits nearer its line cap than its byte cap, so lines are the binding axis there and a prune aimed at bytes would work on the slacker one.
That is the inverse of what the byte-over-lines rule above prescribes for the rest of the corpus, and the two coexist: the rule is about which measure tracks size, this is about which cap binds first.
Re-derive with `wc -lc` and compare against 200 lines and 25 KB.
Past either, the tail is dropped at load and only a write errors.

When recording context cost, record the `/context` total rather than a single row: a known issue shows one row falling while the total stays identical.

## Sources

All verified in the session that produced this note.

- <https://code.claude.com/docs/en/memory>
- <https://code.claude.com/docs/en/context-window>
- <https://code.claude.com/docs/en/hooks>
- <https://code.claude.com/docs/en/skills>
- <https://code.claude.com/docs/en/prompt-caching>
- <https://code.claude.com/docs/en/large-codebases>
- <https://code.claude.com/docs/en/best-practices>
- <https://agentskills.io/specification>
- <https://agents.md/>
- <https://arxiv.org/abs/2602.11988> Gloaguen et al., Evaluating AGENTS.md
- <https://arxiv.org/abs/2605.10039> McMillan, factorial study of configuration-file structure
- <https://arxiv.org/abs/2608.11095> Chakrabarti, Why Does CLAUDE.md Keep Growing
- <https://arxiv.org/abs/2511.12884> Chatlatanagulchai et al., Agent READMEs
- <https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals>
- <https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-for-agents/SKILL.md>
- <https://docs.cline.bot/best-practices/memory-bank>
- <https://cog.readthedocs.io/en/latest/running.html>
- <https://docs.vale.sh/topics/styles>

## Next step

A `/design` taking this note as input, where a change to the global `CLAUDE.md`, to a rules file or to `inject-project-context.sh` is decided.
The hook instruction on `PLAN.md` was confirmed negotiable by the user on 2026-11-06, so the digest and hook-side remedies are in scope there, under the 10 000-character cap.
