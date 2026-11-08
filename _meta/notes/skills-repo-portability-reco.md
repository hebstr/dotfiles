# Restructuring `claude-code-plugins` for agents other than Claude Code

2026-11-08.
Decision asked: how the repository should be restructured so its seven skills run under agents other than Claude Code without losing the workflow, the scope or the quality the plugin form gives them, ruling on the distribution form, the repository granularity and the name.

Verdict: keep the plugin and marketplace form, rename the repository to `hebstr/skills`, keep one repository, and change no skill body for portability.
The premise that a portable layout is something still to be built is wrong: an Agent Skills specification was published as an open standard and adopted as a Linux Foundation project on 2026-11-04, the dominant universal installer reads `.claude-plugin/marketplace.json` directly, and `disable-model-invocation` is read natively by opencode, Cursor and Zed.
So the repository is already portable in the shape it has, and the work left is to stop coupling what need not be coupled.

Scope: the distribution form, the granularity, the name, the ordering of a rename.
Out of scope: rewriting any skill body, the `AGENTS.md` digest, the global `~/.claude`, opencode's own configuration.

## Revised the same day: the target is opencode on `cpd`, and the brief's own constraint is refuted there

The user stated after delivery that portability matters essentially for opencode on `cpd`, the other agents not being a priority.
That refutes the brief's constraint "opencode is already served, so it is not the target", for `cpd` specifically, on the user's own evidence.
`DESIGN-CPD.md` records that opencode 1.19.5 runs there from `~/.opencode/bin` with `opencode run` verified on 2026-11-04, that `opencode-skills-sync` is "not used" because it "reads ~/.claude/plugins/installed_plugins.json, and Claude Code is never installed on cpd", that the harness there is "the most complete harness possible without what is specific to Claude Code, which will never be installed on `cpd`", and that "the plugin skills stay out: `skills.paths` names a link farm that does not exist there", a sentence its 2026-11-04 as-built revision explicitly keeps.

So the seven skills are absent from `cpd`, the machine where the user runs the harness against the 27B.
The portability gap is live rather than forward-looking, and it is narrower than the brief described: one machine with no Claude Code, rather than other people's harnesses.

### Measured 2026-11-08 on `ju-TP`: the farm works and all seven load, after a first measurement that piping made false

`opencode debug skill` prints every skill opencode resolves with its `location`. Run on this workstation with opencode 1.19.5, **redirected to a file**, it lists 66 skills, and all seven of this repository are among them, resolved through the farm: four under `~/.local/share/opencode-claude-skills/audit` and three under `.../workflow`, beside nine from `r-skills`, nine from `r-lib`, six from `posit-dev` and the rest.
So the brief's constraint holds on `ju-TP`: the configured `skills.paths` is read, the deprecated object form works, and opencode consumes the current plugin form unchanged.

**An earlier run in this session concluded the opposite, and it was an artefact of the pipe.** Every attempt had been piped into `rg`, and `_meta/notes/opencode-harness-setup.md` already records the trap in its own words: "`opencode debug skill` is read from a file, not a pipe: piped, its output comes out truncated." Piped, it returned fourteen entries out of 66, none of them the seven. Every conclusion drawn from those runs is void, the farm being inert and configured paths being unread included, and so are the `OPENCODE_CONFIG` control runs, which were piped the same way. What survives from them is one fact the full listing confirms: `disable-model-invocation: true` does not hide a skill from this listing, all seven carrying the flag and all appearing.

**So the gap is `cpd` alone**, and it rests on `DESIGN-CPD.md` rather than on any measurement of mine: no Claude Code there, `opencode-skills-sync` unused for want of `installed_plugins.json`, and the farm directory created empty by the reproduction procedure.

**None of the six verdicts changes.** The route to `cpd` is to reproduce there what `ju-TP` is now measured to do: a clone of the repository, and the farm built from it rather than from a Claude Code cache that will never exist. `opencode-skills-sync` needs no new parsing for that, its `skill_dirs()` already reading `<root>/.claude-plugin/marketplace.json`, selecting each plugin entry by name and printing `<root>/audit/walkthrough` and the rest; what it needs is to stop requiring `installed_plugins.json` and `settings.json` and to drop the `enabledPlugins` filter, none of which `cpd` can provide.
Whether opencode resolves a skill directory straight from a clone, without the farm's symlink layer, is unmeasured and not needed: the farm shape is the one proven here.

The live cost stays the one ruling 3 isolated, and it is now the only thing the `cpd` route has to find out: the six bundled agent definitions are Claude Code plugin components, so `walkthrough`, `blindspot` and `skill-adversary` may fail where they dispatch one, while `sweep`, `sync`, `reco` and `write` have no such dependency. They load on `ju-TP`; whether they run to completion there was not tested either.

## The three premises that were wrong

**There is a published specification, and it is narrow.**
`https://agentskills.io/specification` defines exactly six frontmatter fields: `name` and `description` required, then `license`, `compatibility`, `metadata` and `allowed-tools`, the last marked "Experimental. Support for this field may vary between agent implementations".
There is no `version` field and no invocation-control field.
`metadata` is the sanctioned slot for vendor extensions: "Clients can use this to store additional properties not defined by the Agent Skills spec".
Governance was adopted 2026-11-04 (`GOVERNANCE.md` of `agentskills/agentskills`).

**The portability gap is narrower than "other people's harnesses".**
`npx skills` (`vercel-labs/skills`, Vercel Labs, 38.5k stars) installs a skill into any of 75-plus harnesses, and its own documentation states: "If `.claude-plugin/marketplace.json` or `.claude-plugin/plugin.json` exists, skills declared in those files are also discovered", and "Skill paths declared in a manifest are searched at their declared depth and are not subject to the bounded depth-3 catalog walk".
A third party with no Claude Code installed can therefore consume this repository as it stands.
That is the honest gain over the local link farm, which serves this machine's opencode out of the Claude Code cache, measured 2026-11-08, and so depends on Claude Code being installed.

**Subagent orchestration is not what binds a skill to Claude Code.**
The line runs between a skill that *dispatches* subagents and a skill *declared to run inside* one.
`obra/superpowers`, which ships `dispatching-parallel-agents` and `subagent-driven-development` to sixteen harnesses, states the rule as "Skills name actions, not tools" and rates subagent dispatch "Degradable: if unavailable, those specific skills tell the model to do the work inline or report the missing capability, *never* to invent a `Task` call".
The declarative form is the one that does not travel: in the `npx skills` compatibility matrix, `context: fork` is "No" for all seventeen non-Claude harnesses.
None of the seven skills here uses `context: fork`, so all seven are on the portable side of that line.

## 1. Distribution form: shape A, with the bodies made spec-plain

Keep `.claude-plugin/marketplace.json` and the two plugin groups.
Add no second install path, because the one that matters is maintained by someone else and already reads this manifest.

What shape B would cost, against nothing it gains: the group namespacing that makes `/audit:walkthrough` and `/workflow:reco` distinct commands, the six bundled agent definitions (a plugin component, not a skill one: in `plugin.json` the `agents` key takes "Agent `.md` files. Directories aren't accepted", default location `agents/` at the plugin root), and the eval directories.

The two shapes coexist with no duplicated body, and this is the load-bearing point: one `SKILL.md` per skill, and every per-harness artefact is a manifest or a sidecar beside it, never a copy of the prose.
Precedent at both ends of the spectrum: `obra/superpowers` commits eight per-harness manifest directories over one shared `skills/` tree; `wshobson/agents` generates the per-harness trees and gitignores them, with the rule "Never hand-edit generated files".
The `AGENTS.md` drift objection does not apply to either, because nothing is hand-maintained twice.

One cost of keeping `disable-model-invocation` has to be stated, because it is a hard failure and not a degradation.
The key is not in the specification's six fields, and Claude Code documents that the claude.ai upload path and `package_skill.py` reject any field outside them: "If you include any field the spec doesn't allow, packaging or upload fails with a hard error instead of ignoring the field".
So these seven skills cannot be uploaded as claude.ai personal skills while they carry the flag.
That is a route the user does not use, and it is the price of the gate.

## 2. The gating problem: real, bounded, and already the convention

The specification offers nothing.
Its own client-implementation guide names the key anyway, as the example of a skill to filter out: a client should exclude from the catalog a skill that "has opted out of model-driven activation (e.g., via a `disable-model-invocation` flag)", and "**Hide filtered skills entirely** from the catalog rather than listing them and blocking at activation time".
The same page documents the user-side half: "Users should also be able to activate skills directly... The most common pattern is a **slash command or mention syntax** (`/skill-name` or `$skill-name`)".

Measured, per harness, from each vendor's own documentation:

```
| Harness | Reads `disable-model-invocation` | Explicit invocation |
|---|---|---|
| Claude Code | yes, documented | `/name` |
| opencode | yes, "the same effect as `opencode/autoinvoke: false`" | `@skill-id` |
| Cursor | yes, "only included when explicitly invoked via `/skill-name`" | `/skill-name` |
| Zed | yes, "invocable via slash command or @-mention only" | `/` or `@skill` |
| Codex | no, but `allow_implicit_invocation: false` in a sidecar `agents/openai.yaml` | `$skill` or `/skills` |
| Gemini CLI, Copilot, Goose, Amp, Cline, Roo Code | no mechanism documented | varies, Amp removed user-invokable skills deliberately |
```

So the degradation is not uniform, and the question "is a skill that auto-fires still the same skill" has three different answers.
On opencode, Cursor and Zed the gate is lossless, same key, same semantics.
On Codex it costs one generated one-line sidecar per skill, which is a manifest and not a body copy.
On the six harnesses with no mechanism, the skill is a different skill, and for `write` the project already ruled that this overlap is disqualifying when it dropped the Waza `write` skill over it.
The fallback there is the anti-trigger sentence already present in all seven descriptions, and its standing should not be overstated: a survey of public skill repositories found no instance of that technique, so it is unattested rather than validated.
The one public project that deliberately relies on description-as-gate is `romiluz13/auto-pi`, which stripped the flag from fourteen skills for a Pi port with the acceptance criterion "The skill descriptions are otherwise unchanged (they are the invocation gate)".

The portable direction of travel is documented and contested in the user's favour: `openai/codex` issue 29989, "Support disable-model-invocation in SKILL.md", is open with 62 reactions.

One defect connects to a measurement already in the repository's own `PLAN.md`.
`anthropics/claude-code` issue 78523, "disable-model-invocation: true breaks explicit /skill-name invocation", is open and labelled `bug`: the flag also strips the skill from the listing, so the explicit path intermittently fails.
That is the same mechanism the user measured on 2026-10-17 when the walkthrough orchestrator could not launch a flagged skill by name, and the same filter has been traced in two other harnesses (`openclaw/openclaw` 184918, `openai/codex-plugin-cc` 211).
The correction already applied here, launching the reviewer by path rather than by name, is the right workaround and is upstream-independent.

## 3. Scripts and agents: an asymmetric answer, and not the asymmetry expected

**Scripts, references and templates travel.**
The specification blesses `scripts/`, `references/` and `assets/`, and addresses them by "relative paths from the skill root", with the agent resolving them: "no absolute paths needed".
The three Python scripts and the five reference and template files are portable as they stand.

**`${CLAUDE_PLUGIN_ROOT}` does not travel**, and it is the one addressing coupling to remove.
It is a Claude Code substitution with no equivalent in any other harness's documentation, and it is substituted in exactly two places, "the skill's markdown content, and Bash rules in the `allowed-tools` frontmatter".
Six of its uses are in `audit/blindspot/SKILL.md`, and the remedy is already a `DEFERRED.md` row from 2026-10-10, under the rule written in `audit/sweep/DESIGN.md`: a reading pointer takes the relative form, the variable is reserved for a path a shell command needs.
Applying that row is the portability fix, and it was already owed on other grounds.

**Bundled agent definitions are spec-silent.**
The specification says nothing about them, and its only mention of subagents is one optional paragraph of implementation guidance.
`<skill>/agents/*.md` therefore travels as inert files that no spec-level consumer reads.
In Claude Code they are a plugin component rather than a skill one, which is an argument for keeping the plugin form, not for dropping it.

**The orchestration wording is the remaining coupling, and it is prose.**
`audit/sweep` names the `Agent` tool thirty-six times, `blindspot` seventeen, `walkthrough` sixteen, `reco` nine, `skill-adversary` two, `sync` one, `write` none.
The `superpowers` rule says to name the action rather than the tool, which would make those bodies harness-neutral without changing what they do.
That is a prose pass, it collides with the open `DEFERRED.md` row calling for `/workflow:write` over `audit/walkthrough/SKILL.md`, and it therefore comes last and through that route.

## 4. Granularity: one repository, and neither reopening condition is met

The repository's own `PLAN.md` set the two conditions for revisiting the unified tag: external distribution, or plugins diverging sharply in release cadence.

**External distribution: not met.** No contributors, no known external users, no installed-user base to keep compatible.

**Divergent cadence: not met, and the measurement says something sharper.**
Commit volume does diverge, `audit` 47 commits against `workflow` 11, with only 7 commits touching both.
There is no release cadence for that divergence to appear in: two tags ever, the last `v0.1.1` on 2026-06-03, with 57 commits and 31 unreleased `CHANGELOG.md` entries since.
A per-group version line cannot diverge from a line that has not moved in five months.
The live problem is a dormant release pipeline, and splitting the repository would give two dormant pipelines.

Practice in public skill repositories in late 2026 points the same way, including at the layout `PLAN.md` names as its reference.
`posit-dev/skills` carries 0 tags and 0 releases, and its maintainer declined per-plugin versioning on exactly this structure: "All of our plugins share a single `source: \"./\"`, so there's no per-plugin manifest to version, and from what we can tell, the `version` field doesn't actually enable pinning anyway; it only gates updates... adding version fields would mean keeping a second set of numbers in sync alongside the `version` already in each `SKILL.md`, with no tooling to catch drift".
`anthropics/skills` likewise: 19 skills, plugin groups declared by enumeration rather than by directory, 0 tags, 0 releases.
Where splits happened, the triggers were absent here: `t2vi/arrgh` split because "Plugins break far more often than the app changes", `yo61/claude-skills` abandoned per-plugin release automation for a topology pivot, and `ipapadop/plugins` recorded the price, "Existing installs do not migrate... Skill commands change".
`chris-prener/dev-kit` issue 90 rejected a repository-per-pack in favour of per-plugin tags in one repository, and named the cost that applies directly here: shared files referenced as `../<name>` "probably won't resolve once the pack installs as its own plugin directory".
That cost is concrete in this repository: `blindspot` and `sweep` both read sibling `walkthrough` files by relative path.

The planned additions do not change this.
`design` and `commit` are placed by the coupling criterion of `DESIGN-AGENT-SKILLS.md`, and `commit` reads this machine's hooks and commit gate, so it probably stays in `~/dotfiles/claude/.claude/skills/` and never reaches this repository at all.

## 5. Name: `hebstr/skills`

Three independent arguments retire `agent-skills`, two of them new.

The collision the user flagged stands: `agent-skills` already designates the third-party vendoring route that `bin/.local/bin/agent-skills-update` and the `agent-skills` module of `sys-update` maintain, which `DESIGN-AGENT-SKILLS.md` deliberately keeps separate from the user's own skills.

`agent-skills` is a reserved marketplace name in Claude Code.
The marketplace reference lists it among the official names, `agent-skills` and `anthropic-agent-skills` included, "Reserved unless the marketplace comes from a `github` or `git` marketplace source under `github.com/anthropics/`", and a near-miss counts: a name differing from a reserved one "by a symbol other than an underscore in place of a hyphen" is treated as the same name.
The repository name is not the marketplace name, so `hebstr/agent-skills` would load while the marketplace id stays `hebstr`.
It would sit one step from a reserved identifier, and Claude Code downloads a GitHub marketplace "through a folder named `acme-x-tools`", so the repository would install through a folder named `hebstr-agent-skills`, which is the other candidate.

The name carries no distinctiveness: `addyosmani/agent-skills`, `vercel-labs/agent-skills` and `Govcraft/agent-skills` (a Rust implementation of the specification) are three unrelated prominent things under that name.

`hebstr-agent-skills` stutters on this account (`hebstr/hebstr-agent-skills`) and inherits the local collision.

`hebstr/skills` matches the dominant convention for an account whose handle already carries the scope: `anthropics/skills`, `posit-dev/skills`, `mattpocock/skills`, `vercel-labs/skills`.
All six candidates checked are free on the account.
Since the granularity verdict is one repository, the name does not need to be a family prefix, and `hebstr` already is one at the marketplace level if a split ever happens.

## 6. Ordering: rename first, and the marketplace id never moves

The marketplace id is independent of the repository name, which decides how much wiring moves.
Claude Code takes it from the `name` field of `marketplace.json`, which is `hebstr`, and the clone under `~/.claude/plugins/marketplaces/hebstr`, the cache under `~/.claude/plugins/cache/hebstr/` and `extraKnownMarketplaces.hebstr` all key on it.
Keeping it is also the only safe choice: `cardano-foundation/cardano-dev-skills` issue 133, which analysed this exact question, found that a repository rename "keeps installs working; changing the marketplace or plugin ids is what breaks users", that a plugin id rename "breaks every existing install" with a `renames` map to migrate it, and that for a marketplace id "we found no mechanism at all to rename" one, so "changing it would orphan every existing user".

The repository name sits in two live configuration fields, both `source.repo`: `extraKnownMarketplaces.hebstr.source.repo` in the stow-managed `claude/.claude/settings.json`, and the `hebstr` entry of `~/.claude/plugins/known_marketplaces.json`, which the CLI owns and stow does not.
Plus two git remotes, the source clone and the marketplace clone, and the working directory's own name.
The third grep hit under `~/.claude` is not a site to edit: `plugins/plugin-directory-cache-v2.json` caches the public directory, where the name belongs to `petrovicistefan`, `pagerduty`, `krantideep95` and `lenadweb`.
Of 138 occurrences across `~/dotfiles`, 1 is wiring and the rest are prose and records, 11 of them session-discipline benchmark corpora that are historical and must not be rewritten.

GitHub redirects the operations that matter: "all `git clone`, `git fetch`, or `git push` operations targeting the previous location will continue to function", with three documented exceptions.
GitHub Pages project sites get no redirect, which does not apply here.
GitHub "will not redirect calls to an action hosted by a renamed repository", so any self-referencing action in the two workflows has to be checked, the third-party pinned actions being unaffected.
And the old name must never be recreated, because "redirects to the renamed repository will no longer work".

What the four-step post-install chain of `PLAN.md` requires after a rename is less than a content change requires, because no content moves and the sha does not change.
Its third step, `claude plugin update <plugin>@hebstr`, has nothing to fetch.
What must happen is to repoint the two `source.repo` fields and the two clone origins, then `claude plugin marketplace update hebstr` to re-validate, then restart.
Edit the registration in place rather than removing and re-adding it: a re-add after a rename raises an "already added from a different source" conflict.

Why the rename comes first: it touches only install wiring, while the restructuring touches manifests and bodies, so doing it first means the post-install chain runs once against the final identity.
It is also cheapest now, with no release pending and no external user to orphan.

## Quality gates: two upgrades and one fragility

The quality bar is to keep the current gates or replace them with something at least as strong.
Two replacements are stronger, and both come from primary documentation.

The hand-rolled Python check that every `skills:` path holds a `SKILL.md` is a subset of `claude plugin validate`, which is documented as "the authoritative check for a manifest", reports unknown keys, missing or escaping paths, reserved names and plugin-name collisions, and takes `--strict` to "turn warnings into failures in CI".

The specification ships its own validator, `skills-ref validate ./my-skill`, which "checks that your `SKILL.md` frontmatter is valid and follows all naming conventions".
That is the gate that would mechanically prove the bodies stay spec-clean, which no current gate does.
It is not settled that it can be used as is: `Govcraft/agent-skills` issue 9 reports `validate` rejecting runtime-specific frontmatter such as `disable-model-invocation`, so it may need a per-field allowance or a non-blocking run.

The fragility: `"strict": false` does nothing in this manifest today, because with no `plugin.json` "the entry is the manifest regardless of `strict`".
Adding a `plugin.json` later while the entries still declare `skills` would make the plugin fail to load with `Plugin <name> has conflicting manifests`.
Either drop the dead `"strict": false`, or record that no `plugin.json` may be added.

## What public sources cannot settle, and the measurement that would

- **Whether `npx skills` resolves this repository's manifest shape.** The declared-depth behaviour is documented, the two-plugin `"source": "./"` shape with enumerated skill paths is not exercised in the documentation. Measurement: `npx skills add hebstr/skills` into a scratch directory after the rename, and check that all seven arrive with their `scripts/`, `references/` and `templates/`.
- **Whether `skills-ref validate` tolerates `disable-model-invocation`.** One open issue says it does not. Measurement: run it against one skill directory.
- **Whether the deprecated opencode config form is worth migrating.** `opencode.json` declares `skills: {paths: [...]}`, which the published schema at `https://opencode.ai/config.json` marks `"deprecated": true` while the documented form is a top-level `skills` array. Measured 2026-11-08: the object form works, all seven skills resolving through it, so the migration is hygiene rather than a repair. Measurement that would settle the rest: whether the array form resolves the same 66 skills, run with the output redirected to a file and never piped.
- **Whether a nested agent can launch background `Agent` calls.** Already an open `DEFERRED.md` row, unchanged by any of this.

## Decomposition, ordered by dependencies

**Minimal viable core, settling decisions 4, 5 and 6 with no skill body touched:** rename the repository to `hebstr/skills`, keep the marketplace id `hebstr`, keep one repository, keep the plugin form. Portability to a third party with no Claude Code follows from the manifest that already exists.

Reordered for the `cpd` priority: step 0 comes before everything, it is independent of the rename, and it needs no change to the repository.

0. **Serve the seven on `cpd`, by reproducing the farm that `ju-TP` is measured to use.** Clone the repository there beside the dotfiles clone, and give `opencode-skills-sync` a clone source so it builds the farm from `<clone>/.claude-plugin/marketplace.json` rather than from a Claude Code cache that will never exist: dropping the `installed_plugins.json` and `settings.json` requirements and the `enabledPlugins` filter is the whole change, `skill_dirs()` already doing the enumeration. Then measure on `cpd`, output redirected to a file and never piped: that all seven appear in `opencode debug skill`; that `write` and `reco` run to completion on the 27B; whether `OPENROUTER_API_KEY` has an outbound path from that workstation, which the three cross-provider skills need; and whether `walkthrough`, `blindspot` and `skill-adversary` survive dispatching a bundled agent definition opencode does not read. Depends on nothing.
1. **Rename and rewire.** GitHub rename; both clone origins; the local directory name; `source.repo` in the stow-managed `settings.json` and in `known_marketplaces.json`; `claude plugin marketplace update hebstr`; restart; check the two workflows for a self-referencing action. No dependency.
2. **Sweep the references.** Prose and tracking files across `~/dotfiles` and the repository's own `.claude/`, excluding the 11 session-discipline benchmark shards, which are records. Depends on 1.
3. **Strengthen the gates.** Replace the manifest check with `claude plugin validate --strict`; rule on the dead `"strict": false`. Independent of 1, cheaper after it.
4. **Remove the addressing coupling.** Apply the open `DEFERRED.md` row: the six `${CLAUDE_PLUGIN_ROOT}` reading pointers in `blindspot` become relative paths, the variable staying only where a shell command needs it. Independent, and owed anyway.
5. **Measure the portability claim.** The four measurements above, after 1 so the installer is pointed at the final name. Depends on 1 and 4.
6. **Add the spec-clean gate.** `skills-ref validate` in CI, blocking or not according to what 5 found. Depends on 5.
7. **Make the three subagent skills degrade on opencode, if step 0 shows they must.** The portable shape is the one `superpowers` uses: the body names the action, and the per-harness mapping lives outside it. Whether that means an opencode agent definition stowed beside the others, or the fallback wording the `superpowers` rule prescribes, depends on what step 0 measures. Codex sidecars stay out: not a priority.
8. **The actions-not-tools wording pass.** Through `/workflow:write`, after the open `DEFERRED.md` prose row on `audit/walkthrough/SKILL.md`, which it must not collide with. Last.

Step 0 is the one that serves the stated priority, and it changes nothing in the repository.
Steps 1 to 4 are the core and need no new mechanism.
Steps 5 and 6 convert a documented claim into a measured one.
Step 7 now has a consumer, which it did not before the priority was stated, and step 8 still waits on the prose row.
