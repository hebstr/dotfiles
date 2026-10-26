---
name: Closed tool evaluations, their verdicts and what reopens each
description: "Seven closed decisions, each with its date, its verdict and its reopening trigger: arity against the air + jarl R gate, the uditgoenka/autoresearch skill, gortex as a code-intelligence layer, pnpm against the npm footprint, acquiring SAS on Ubuntu, the git write guard's scope over sparse-checkout and submodule update, and the dotfiles YAML gate; each analysis is already done, so read the verdict rather than redo it"
metadata:
  type: project
---

Each entry below cost a full session of measurement or reading, and each is closed. The point of the note is the same in all seven cases: do not re-run the evaluation, and do not re-propose the tool, unless the entry's revisit trigger has actually fired. Four entries point at a `~/dotfiles/_meta/notes/` write-up that holds the full trace; the three that do not (gortex, pnpm, the git guard's scope) carry their measurements here, no better copy existing.

## arity, rejected as the air + jarl replacement, 2026-09-10

Arity (jolars/arity), a Rust formatter + linter + LSP for R, was tested against `air` 0.11.0 and `jarl` 0.6.0, the versions installed that day, and not adopted. Both blockers are structural, so a version bump does not reopen the verdict: on 2026-10-09 air read 0.12.0 and jarl 0.6.0. The binary sits in `~/.local/bin/arity`, outside the gate, kept for watching the project; `rm ~/.local/bin/arity && rm -rf ~/.cache/arity` reverts it.

- **The formatter recompacts hand-written line breaks.** No equivalent of air's `persistent-line-breaks`, and the absence is a design decision pinned by the repo's own fixture `crates/arity-formatter/tests/fixtures/formatter/call_user_line_breaks/input.R`, whose first line reads `# Unlike air, Arity doesn't cater to user line breaks`. Measured across the fourteen projects carrying an `air.toml`: air reports one file, arity would rewrite roughly nine in ten.
- **`arity lint --fix` strips rlang's `!!`.** The `comparison-negation` rule reads `!!var < inf` as the double negation R's grammar actually parses, and its fix is classed *safe*, so it applies without `--unsafe-fixes`. The corpus carries 341 `!!` lines across 110 files. Contrast: jarl refuses to apply any fix outside a version-controlled tree.

Revisit trigger: an upstream `persistent-line-breaks` equivalent, or a `comparison-negation` carve-out for rlang injection. Neither is on a published roadmap; arity has no milestones and no open issues, its planning living in an unpublished `TODO.md`.

**Why:** the two blockers are structural rather than version-bound, so re-testing on the next release repeats a full session for the same answer.
**How to apply:** keep `air format` then `jarl check` as the R gate ([[feedback_r_environment]]). Do not propose arity as a drop-in replacement. `arity lint --select` restricted to the `packaging` and `documentation` families stays a live option for `R-hebstr` and `R-edstr` roxygen and DESCRIPTION checks, ground jarl does not cover; it never invokes the formatter. Full trace, two undocumented findings included, replayable with `showboat verify`: `~/dotfiles/_meta/notes/arity-trial.md`.

## uditgoenka/autoresearch, not installed, 2026-09-11

The Claude Code skill `uditgoenka/autoresearch` (v2.2.2, a generalisation of Karpathy's autoresearch) was evaluated in full and not installed.

**Why:** its only net contribution is the keep/discard metric loop, which commits once per iteration on a clean tree, while `settings.json` denies `git reset`, `git checkout`, `git stash` and `git restore`, and, since 2026-09-25, lets `git add` and `git commit` run only through the `commit` skill with a permission prompt on every call: the loop stops at its first iteration. Its 13 other commands duplicate ouroboros, `/audit:*`, `posit-dev:describe-design`, `security-review` and `/loop`, and the plugin install would add 9 global Node hooks.
**How to apply:** three conditions reopen the decision: a throwaway branch where automatic commits are acceptable (the candidate is `covr` coverage of `R-hebstr` and `R-edstr`), a fast scalar metric appearing on a project of the stack, or a release that decouples the loop from git. If ever adopted, copy the skill and commands by hand (option C of its README), never the plugin, so as not to inherit the hooks. Analysis, measurements and reopening conditions: `~/dotfiles/_meta/notes/autoresearch-skill-reco.md`.

## gortex, rejected as a code-intelligence layer, 2026-10-07

Gortex (zzet/gortex), a Go code-intelligence engine indexing repositories into a SQLite knowledge graph served over CLI, MCP, HTTP and a web UI, was evaluated and not adopted. Nothing was installed: the verdict rests on the published docs and on the extractor source, read through `gh api`.

Three blockers, none reachable by configuration:

- **`.qmd` chunk bodies produce no edges.** `internal/parser/languages/quarto.go` emits one node per top-level frontmatter key, one per heading-delimited prose section, and one `KindFunction` per executable chunk named by its label. The chunk body is never parsed into its host language, so no `calls` and no `imports` edge comes out of a `.qmd`. The one question worth the install (what breaks across `ipl-sca`, `md-nesrine`, `eds-avc` if a `hebstr` or `edstr` export changes) is answered from call sites that live mostly inside `.qmd` chunks, so the blast radius would be silently partial, which is worse than an `rg` whose limits are known.
- **No R language server in the matrix.** `docs/lsp.md` lists sixteen servers, none for R, so every R edge stays at the `ast_inferred` provenance tier and is never confirmed. No roxygen, `NAMESPACE` or `DESCRIPTION` awareness either, so a package's export surface is not an object of the graph.
- **The install takes over the hook surface.** `gortex install` writes `~/.claude.json`, `~/.claude/settings.json`, `~/.claude/skills/gortex-*`, `~/.claude/commands/`, `~/.claude/agents/`; `gortex init` adds marker-guarded blocks to `CLAUDE.md` and `AGENTS.md`. Hooks land on eight events (PreToolUse, PostToolUse, PreCompact, Stop, SessionStart, UserPromptSubmit, SubagentStart, SubagentStop) with a PreToolUse `deny` posture meant to refuse file reads the graph can serve. Five of those eight are already occupied here by fourteen hooks, in a stow-managed, git-tracked, Syncthing-replicated `settings.json`. `gortex clean` reverts the project level; there is no machine-level uninstall.

Two findings worth keeping about the project itself. Its R extraction is better than its own documentation claims: `docs/languages.md` files R under the regex tier ("function defs; library / require / source"), while `internal/parser/languages/r.go` runs the forest tree-sitter grammar first and layers regex passes for S4 (`setClass` / `setGeneric` / `setMethod`), `R6Class`, `setRefClass`, S3 `generic.class` methods against nineteen base generics, and namespace-qualified `pkg::fn` calls, over `.R`, `.r` and `.Rmd`. And the headline "50x fewer tokens" is a symbol-lookup figure measured on gortex's own Go repository, where the baseline is `rg` plus whole-file reads; on a natural-language query the same table shows gortex costing more (1,825 tokens against 415), and `BENCHMARK-SWE.md` is an empty template, every cell `TBD`, so no end-to-end task-success evidence exists.

Revisit trigger: a Quarto extractor that parses chunk bodies into their host language, or an R entry in the LSP matrix. Either one alone moves the first two blockers; the third stays a `--no-hooks` install with a hand-written MCP stanza.

**Why:** the question "could a code graph help here" looks obviously yes in the abstract, and the answer turns entirely on two file types that the project's own documentation misdescribes, so re-asking it without re-reading `quarto.go` and `r.go` repeats a full session for the same answer.
**How to apply:** do not propose gortex, nor a graph-indexer substitute, for the hebstr / edstr cross-project impact question. Answer it with `rg -n 'hebstr::<fn>'` across the project roots, which covers the `.qmd` chunks no such indexer reads today ([[reference_hebstr_easy_out_subdir]], [[project_hebstr_add_note_migration]]). Two practices from the reading were kept: the SessionStart matcher now includes `clear` (the rules-marker cache survived a `/clear` and suppressed every re-injection), and the MCP exposure discipline applies to `litrev-mcp`, whose sixteen tools carry 15,975 characters of docstrings.

## pnpm, rejected against the npm footprint, 2026-10-24

pnpm was evaluated against the actual npm footprint of this machine and not adopted. Nothing was installed: the verdict rests on local measurement plus pnpm, npm, Node and stylelint official docs.

The footprint is four manifests, all tooling, no workspace and no JS application:

- `~/.local/share/css-gate/` (stow package `css`): prettier, stylelint, stylelint-config-standard-scss pinned exact, `package-lock.json` v3 tracked, `node_modules/` ignored, config beside its own `node_modules` so `extends` resolves from there
- `bin/.local/bin/css-toolchain-update`: wraps `npm install --save-exact`; 69 lines across three bats files cite `npm`, including a full `npm` stub in `css-toolchain-update.bats`
- `sys-update` and `sys-cleanup`: `npm update -g`, `npm cache verify`
- `~/.npmrc` (machine-local, never stowed): `prefix=~/.npm-global`, `allow-scripts=opencode-ai`; one global package, `opencode-ai`
- `quarto-hebstr-doc`: repo-local install, `npm ci` in `render.yml`, two prek hooks on `node_modules/.bin/`, pins bumped by a monthly Dependabot `npm` group (see `rules/css.md`, "Commit gate (prek)")

Four measurements that decide it:

- **The disk gain is marginal.** pnpm dedups by hardlink across projects, and the only duplication here is two toolchain trees of about 30 MB, which is therefore the ceiling. Measured on 2026-10-24 they sat on different versions, so only part of the transitive set would have linked; `b772d84` of `quarto-hebstr-doc` aligned them to the gate's pins the same day, which reaches that ceiling and goes no further. The large posts are elsewhere: 1.4 GB in `~/.npm/_cacache` and 410 MB of global package.
- **The strictness gain is already acquired.** `stylelint-config-recommended-scss` declares `stylelint-scss` and `postcss-scss` as real `dependencies`, and `postcss` is a dependency of `stylelint` itself. None of the 123 packages npm hoists to the gate's root (112 top-level entries, six of them scope directories) is reached by phantom resolution, so pnpm's isolated layout would find nothing.
- **npm 12 ships both transferable arguments.** npm 12.2.1 (2026-10-15, `node ^22.22.2 || ^24.15.0 || >=26.0.0`) documents `install-strategy=linked` ("install in node_modules/.store, link in place, unhoisted") and recommends it to catch phantom dependencies, and npm 12.0.0 blocks dependency lifecycle scripts by default behind an `allowScripts` policy.
- **The premise is population-dependent.** Stack Overflow Developer Survey 2025, n = 24,473: npm 56.8%, Yarn 21.1%, pnpm 13.4%. State of JS 2025 monorepo tools: pnpm 3,940 responses against npm Workspaces 2,129. pnpm leads among monorepo users and trails badly in the general population; this footprint is the second case.

Two upstream facts worth keeping. pnpm's own docs concede the layout breaks tools (`publicHoistPattern`, default `[]`: "useful when dealing with some flawed pluggable tools that don't resolve dependencies properly"), and pnpm#8378 removed `*eslint*` and `*prettier*` from its defaults in October 2024, after which prettier 3.5.3 was reported as finding no plugin at all without the pattern put back. And pnpm cut two majors in four months (11.0.0 on 2026-04-28, 12.0.0 on 2026-08-26, a Rust rewrite), dropping `onlyBuiltDependencies` in 11, against an npm that arrives with Node from apt and does not move.

Revisit trigger: a real monorepo or multi-package Node project, which is the one population where the evidence supports pnpm. Decide it per project then, without touching the gate.

**Why:** "pnpm is the current standard" is true enough in JS app development that it reads as settled, and it inverts once the question is scoped to a config with one private toolchain. Re-asking it without re-measuring the plugin declaration chain and re-checking npm's current feature set repeats a full session for the same answer.
**How to apply:** do not propose migrating the CSS gate, `css-toolchain-update`, the `sys-update` / `sys-cleanup` npm modules or `~/.npmrc` to pnpm. If strictness is ever wanted on this chain, the lever is npm's own `install-strategy=linked`, tested first because npm 12 also makes unknown `.npmrc` keys throw and stops honouring `npm-shrinkwrap.json`, and because `npm install -g npm@12` under the user prefix would shadow the apt-managed npm that `rules/install.md` assumes. Corepack is end of life for this purpose: Node's v24 docs state it is removed from Node v25 onward, and pnpm 12's install page no longer mentions it, so the `corepack 0.36.0` on this machine is a vestige.

## SAS on Ubuntu, researched and deferred, 2026-10-06

The three ways to get SAS on ju-TP were researched in full and the decision was deferred by the user ("on fera ça plus tard").

**Why:** three facts close the space. SAS University Edition ended 2021-08-02, so no free local SAS exists. SAS 9.4 Foundation supports only RHEL, Oracle Enterprise Linux and SLES, never Ubuntu. The only local option left is the paid SAS Analytics Pro container (licence JWT from `my.sas.com`), whose supported host is RHEL 8.10/9.x with Docker Desktop or Podman, so Ubuntu 24.04 is out of support there too. The free path, SAS OnDemand for Academics, is browser-only, non-commercial, and sends data to SAS infrastructure, which rules it out for SNDS or any health data.
**How to apply:** the recommendation on hold is to start with OnDemand for Academics to confirm SAS is actually needed, then, if real data is involved, quote SAS France for Analytics Pro and run the container in a Rocky 9 VM (4 GB of the machine's 15) rather than out of support on Ubuntu. Two things need a fresh check at that point: whether a free Altair SLC community edition still exists under Siemens, and the actual quote, since the ~$1,850/year figure comes from third-party aggregators and not from SAS. Reading `.sas7bdat` without SAS needs only `haven::read_sas()`. Voies, concrete steps, host requirements and verified sources: `~/dotfiles/_meta/notes/sas-install-reco.md`.

## sparse-checkout and submodule update, left outside the git write guard, 2026-10-07

`git sparse-checkout set` and `git submodule update` are not in the gated verbs of `git-write-guard.sh`, and the decision is to leave them there. Both names suggest a working-tree rewrite on the level of the two forms the guard does deny ("git read-tree -u, which overwrites working tree files", "git checkout-index -f, which overwrites working tree files"), and that analogy is what the measurements refute.

Measured on git 2.55.0, in throwaway repositories:

- `git sparse-checkout set keep`, with a modified tracked file and an untracked file under the excluded directory, warned `The following paths are not up to date and were left despite sparse patterns` and left both in place with their content. Only files identical to HEAD leave the working tree, `disable` restores them all, and the INTERNALS section of the installed manual has the skip-worktree bit hide an unpopulated file's absence, so nothing surfaces as a deletion in `git status` for a later `git add` to stage.
- `git submodule update` on a submodule already at its pinned commit was a no-op and left the dirty file; it runs a non-forced checkout otherwise. Only `--force` discarded the local modification, while leaving the untracked file.
- `fdfind -H -t f '^\.gitmodules$' /home/julien --max-depth 4` returns nothing: no submodule exists here.

Revisit trigger: a project gaining a submodule, which would make `git submodule update --force` the one candidate worth a deny rule.

**Why:** the guard's threshold is losing working-tree content the tracking verification sealed, which neither bare form crosses, and a reviewer reading the verb list sees two obvious holes and re-proposes closing them from the names alone. The refutation costs two scratch repositories to rebuild.
**How to apply:** do not propose gating either verb in `git-write-guard.sh` or in the `deny` list of `settings.json` without a fact these measurements do not cover. The permission layer behind them is already recorded: `permissions.allow` carries a bare `"Bash"`, so every command absent from `deny` and `ask` runs with no dialog ([[reference_claude_code_best_practices]]), which is the posture, not an oversight to patch verb by verb. The guard's own suite pins its fail-closed branches, so a new gated verb needs a case there ([[project_claude_dir_local_only_repo]]).

## The dotfiles YAML gate, deferred, 2026-07-30

Researched via `/workflow:reco`, then deferred by the user. Nothing was installed, no config written, no hook added.

Conclusions that survive without reopening the research:

- **Formatter is prettier, not yamlfmt.** yamlfmt converts `|` block scalars to escaped strings (upstream issue #185, open, labelled `yaml_v3_problem`), and `run: |` blocks are exactly the content of the four repos with GitHub Actions workflows. prettier is already pinned in `~/.local/share/css-gate/` and already tracked by `sys-update`'s `css-toolchain` module, so it adds no maintenance surface. See [[project_qmd_format_hook]] for the neighbouring formatter split.
- **Linter is yamllint via `uv tool install`.** The former blocker is cleared: the npm `yaml-lint` 1.7.0 package that owned `/usr/local/bin/yamllint` was uninstalled 2026-09-25 (`.claude/PLAN-ORPHANS.md`, pass of 2026-09-24), and that path no longer exists. The real yamllint is not installed.
- **`actionlint` on `.github/workflows/` only**; that is the one class with no existing coverage.
- **No schema validation on Quarto configs.** SchemaStore has zero Quarto and zero pkgdown entries (catalogue inspected directly, 1402 schemas), and `rules/quarto.md` already forces a full `quarto render` on any `_quarto.yml` edit, which is stricter than a generic schema.

**Why:** the research cost two parallel web agents and a round of URL verification, and the note captures the reasoning that overturned the obvious choice (yamlfmt), which is not recoverable from the tool docs alone.
**How to apply:** if the YAML gate comes back up, read the note first and start at its "Suite proposée" section (install yamllint, measure violations on existing files, only then write `rules/yaml.md`). Do not re-run `/workflow:reco` on this topic. Full write-up: `~/dotfiles/_meta/notes/yaml-gate-reco.md`.
