---
name: poc
description: >
  User-invocable ONLY via `/poc <candidate>`.
  Does not auto-trigger on mentions of "should I install X", "is this tool worth it", "evaluate this tool", "worth adopting", "proof of concept", "PoC", or French equivalents ("est-ce que j'installe X", "cet outil vaut le coup", "évaluer cet outil", "tester cet outil", "preuve de concept").
  The pass deciding whether a candidate tool enters this machine's toolchain or its Claude Code harness.
  Not for: acquisitions, licences and pricing, hardware, OS upgrades, which keep the `_meta/notes/<subject>-reco.md` convention without this procedure; an externally grounded recommendation on a question that is not local (use `/workflow:reco`); choosing between ways of implementing something here (use `/design`).
disable-model-invocation: true
---

# Deciding whether a candidate tool enters this setup

This skill takes a candidate tool, a binary, a plugin, an MCP server or a harness extension, and returns a verdict on whether it enters this machine.
A rejection is a first-class verdict: most recorded instances of this pass ended in a rejection or a deferral, one adopted under a split verdict, and the yield of a rejection is the concepts it leaves behind.

Install nothing, and write no code for the candidate.
The one trial this pass allows is a gate the user runs, after all the reading.
Beyond its note, its memory entry and the backlog row a stopped gate leaves, the pass writes only what a transplanted concept changes.

Conduct the conversation in the user's language, whatever the language of this text.
The note is written in English, per `rules/claude-files.md`.

Record the question the candidate is supposed to answer, in the user's own words, before anything else.
Step 2's stop condition measures the candidate against it, the entry check needs it to tell a covered question from a new one, and the note restates it.

## Before step 1: check the verdict does not already exist

Grep the candidate's name across `~/dotfiles/_meta/notes/`, the project's `.claude/*.md`, and the memory index `~/.claude/memory/MEMORY.md`.

```
rg -il --hidden '<candidate>' ~/dotfiles/_meta/notes/ .claude/ ~/.claude/memory/MEMORY.md
```

`--hidden` is load-bearing: without it `rg` skips `.claude/` entirely and the check reports no earlier verdict while one sits there.
A `*-reco.md` note, a `project_<tool>_evaluation.md` memory or a `DEFERRED.md` row means the pass already ran: cite it by name, give its verdict and its revisit trigger, and ask whether the invocation reopens it.
Reopen only on a fact the earlier pass did not have, which is normally the revisit trigger having fired.
The recorded rejections say in their **Why** line that re-running them costs a full session for the same answer.

## 1. Read the forge state

Start from the project's own public record, which the global baseline does not prescribe a command for.

The candidate arrives as a name, so resolve it to `<owner>/<repo>` first and say which project you resolved it to.
A name matching several projects goes to the user rather than to a guess: a wrong repository that exists reads consistently through step 1 and step 3, which verify it against itself.

```
gh api repos/<owner>/<repo> --jq '{created_at, pushed_at, archived, license: .license.spdx_id, open_issues_count, subscribers_count}'
gh api 'repos/<owner>/<repo>/contributors?per_page=100' --jq '[.[] | select(.type != "Bot")] | length'
gh api repos/<owner>/<repo>/releases/latest --jq '{tag_name, published_at}'
gh api repos/<owner>/<repo>/milestones --jq 'length'
```

A 404 here is an answer rather than an error to investigate: `releases/latest` exits 1 on a project that has published no release, which is itself a reading of the project.
A 404 on the repository call instead means the name is wrong, or the repository is private, moved or deleted, and that is where to stop and resolve the name.

What the answers are for: age against last push tells whether the project is alive, the licence decides whether it can be used here at all, and the maintainer count plus the milestone count tell whether a fix you would depend on has anyone to write it and any published plan to land in.
Arity failed on exactly that composite: no milestones, no open issues, planning in an unpublished `TODO.md`, one author against bots for the rest, and `bump-minor-pre-major` set, so breaking changes land in minor bumps.

When the tool ships through a registry, read the registry too, since the forge does not carry distribution facts: `cargo info <crate>`, `npm view <pkg>`, or `curl -s https://pypi.org/pypi/<pkg>/json | jq '.info | {version, license, requires_python}'` for PyPI, which the uv CLI has no equivalent lookup for.
Record the version actually published and the install command it implies, because the next steps must be read against that version and not against the default branch.

## 2. Map the candidate onto this machine's actual state

This is the kill switch, and it fires more often than any other step.

The question is what is actually installed and actually configured here, read from the machine and never from memory, per the global baseline.
The language stack is the facet that bites most often: a tool that cannot reach R, Quarto, or the host language inside a `.qmd` chunk cannot answer the question that would justify installing it.
Gortex died here, its Quarto extractor emitting one node per executable chunk and never parsing the chunk body, so the cross-project impact question that motivated the install would have come back silently partial.

The facet is wider than the stack, and the YAML gate is why.
That pass rested on `/usr/local/bin/yamllint` being yamllint, while the binary was a symlink to npm's `yaml-lint` 1.7.0, a parse checker with no style rules.
So resolve the names the candidate would replace or sit beside before comparing anything against them:

```
command -v <incumbent> && readlink -f "$(command -v <incumbent>)" && <incumbent> --version
```

Name the corpus the verdict will be measured against while you are here, because step 3 and the trial gate both need it: the real files of this machine, chosen independently of the tool under test.
A candidate that no corpus of files can measure names the cost that stands in for one: the context an MCP server's tool descriptions consume in every session, or the hook events a harness extension claims against those in use.

If the candidate's load-bearing capability does not reach what it must reach here, stop at this step and write the rejection.
The remaining steps price an adoption that is already ruled out.

## 3. Verify every verdict-carrying claim at its source

Documentation and headline numbers are claims about the tool, not readings of it.
Verify each one that carries the verdict, the corpus behind a number included.
`gh api --header 'Accept: application/vnd.github.raw' repos/<owner>/<repo>/contents/<path>` reads a file without cloning, at any size.
The base64 form of that endpoint (`--jq '.content' | base64 -d`) returns `encoding: "none"` and an empty `content` at exit 0 above about a megabyte, so a benchmark table or a corpus file reads as empty rather than as unread.

Two kinds of divergence have both already appeared here.

A documented capability can be absent from the implementation, or present where the documentation denies it.
Gortex's `docs/languages.md` files R under its regex tier while `internal/parser/languages/r.go` runs the tree-sitter grammar first and layers S4, R6, `setRefClass` and S3 passes over it, so the documentation understated the tool in one place and the source contradicted it in another.
The `pdf-inspector` documentation promises "Hyphenation | Rejoins words broken across lines", and the real corpus left 242 words cut against 11 for poppler.

A headline number is a measurement with a corpus and a baseline, and both decide what it transfers to.
Gortex's "50x fewer tokens" is a symbol-lookup figure measured on gortex's own Go repository against `rg` plus whole-file reads, the same table shows it costing more on a natural-language query, and `BENCHMARK-SWE.md` is an empty template with every cell `TBD`.
The "Tables (TEDS) 0.814" of `pdf-inspector` comes from opendataloader-bench, 42 documents, an older version, and a metric that penalises no invented table, which is the defect the real corpus then showed at 47 percent of cells wrong.

Read the upstream issue tracker for the defect you are about to measure before measuring it.
The `pdf-inspector` table defects were all open upstream (#537, #498, #219, #291, #297, #296), which turned a measurement into a confirmation and gave the revisit trigger its exact wording.

## 4. Price the harness collision

A tool that touches the Claude Code harness costs more than its disk footprint, and nothing else in this pass or in the baseline prices it.
Name the surface directly rather than discovering it.

What the installer writes, asked of its own documentation and its install script.
Gortex's installer is the recorded instance of a tool that writes all of them, so its footprint is the starting set rather than the surface: `~/.claude.json`, `~/.claude/settings.json`, `~/.claude/skills/`, `~/.claude/commands/`, `~/.claude/agents/`, plus marker-guarded blocks appended to `CLAUDE.md` and `AGENTS.md`.
A plugin candidate adds `~/.claude/plugins/`, machine-local and untracked, and the `enabledPlugins` and `extraKnownMarketplaces` keys of `settings.json`.
Which of those are local and which reach the repository is a `ls -la ~/.claude` away, and the answer decides how much a write costs.
Stow-managed and therefore git-tracked and Syncthing-replicated as of 2026-10-08: `CLAUDE.md`, `settings.json`, `hooks`, `memory`, `rules`, `statusline.sh`, and one directory link per skill under `skills/`.
Machine-local: `~/.claude.json`, and `commands/` and `agents/`, which do not exist, so an installer creating them creates untracked directories.

Hook events claimed against events in use:

```
jq -r '.hooks | to_entries[] | .key as $e | .value[] | .hooks[] | $e' ~/.claude/settings.json | sort | uniq -c
```

Read on 2026-10-10: fourteen hooks across seven events (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, `Notification`, `InstructionsLoaded`).
A candidate claiming a `PreToolUse` deny posture, as gortex does to refuse file reads its graph would serve, collides with the occupied events rather than adding to them.

Permanent MCP tool surface, when the candidate ships a server: every tool description is loaded in every session for the life of the install.
The local reference point is `litrev-mcp`, whose sixteen tools carry 15,975 characters of docstrings.

Then ask what reverts.
Gortex has a project-level `clean` and no machine-level uninstall, which is a cost paid at install time and not recoverable later.

## Contained-trial gate

Everything above is reading, and reading settles most candidates.
Reaching this gate means the reading did not settle it.

State, and then stop:

- what the trial must exercise, which is the deciding form of the question and never a convenient proxy, per `feedback_probe_must_test_the_deciding_form`;
- the corpus it runs against, named in step 2;
- the containment conditions: the binary in the session scratchpad, every index or output path given explicitly, no write to any config file, no installer run;
- the command, ready to paste.

The user runs it.
`.claude/DEFERRED.md` assigns the PoC to the user in its cloudflared entry of 2026-09-20 ("User's PoC on a trivial case; the chantier opens only if it validates the tool"), and that is the local precedent.
Never install in order to evaluate.

A gate the same conversation does not resolve persists as a row in the project's `.claude/DEFERRED.md`, carrying the reading of steps 1 to 4, the trial's command and the condition that would reopen it, so a later invocation reads that row instead of re-running the reading.
The cloudflared entry cited above is that shape.

## 5. Decide

One verdict, with the two things a verdict without them cannot be acted on later.

The revisit trigger: the specific change that would overturn the verdict, named precisely enough to be recognised when it lands, which is a published upstream change for a rejection and the event that would settle the question for a deferral.
Arity's is an upstream `persistent-line-breaks` equivalent or a `comparison-negation` carve-out for rlang injection; gortex's is a Quarto extractor that parses chunk bodies into their host language, or an R entry in the LSP matrix.
"Revisit in six months" is not a trigger.

The revert path: the exact commands that undo the install, written whether or not the verdict adopts the tool, because a trial binary left on the machine needs them too.
Arity's shape: `rm ~/.local/bin/arity && rm -rf ~/.cache/arity`.
A pass that stopped at step 2 reached no trial and fetched nothing, so its revert path says so rather than naming commands for an install that never happened.

When the verdict is partial, split it by question rather than averaging it.
The `pdf-inspector` pass adopted `detect-pdf`, adopted `pdf2md` under a routing rule, and built nothing for maintenance, as three answers to three questions.

## 6. Persist

### The note

`~/dotfiles/_meta/notes/<tool>-reco.md`, in English.
This template is the authority for the shape; `pdf-inspector-reco.md` is the fullest worked instance of the pass and is read as an example, for neither its headings nor its French, both of which predate this template.

```
# <tool>: <the decision asked for>

<absolute date>. Decision asked: <the question, as a question>.

## Restating the question

<the undecidable request split into questions whose answers can diverge>
<what "done" means here>
<out of scope>

## The tool

<forge and registry state from step 1, dated, with the version actually read>

## Protocol

<corpus, chosen independently of the tool; comparator; the metrics, and which are objective>

## Results

### <dimension>: <the verdict on it>

## Decision

<one answer per question of the restatement>

### Routing rule kept

<only when something is adopted, and only if the rule is expressible without case-by-case judgement>

### Usage warning

<what the tool reports that must not be read as it looks>

## What stays uncovered

<the holes the verdict leaves open, so none reads as filled>
```

A pass that stopped at step 2 measured nothing: it drops `## Protocol` and `## Results`, and its `## Decision` carries the capability gap that ended it.
Each `###` heading under `## Results` makes a claim rather than labelling a topic: "Reading order: decisive gain", "Hyphenation: regression".
Cite code and prose by name, never by line number, per the "Cite by name" rule of `rules/claude-files.md`.
Use absolute dates.
A re-measure is appended as a dated section that contradicts the earlier one in the open, never a rewrite of it.

### The concepts worth transplanting

What a rejected pass leaves behind is usually a practice rather than a verdict.
Name what the reading taught that applies without the tool, and act on it in the same pass: the gortex session's output was the `SessionStart` `clear` matcher fix, commit `e13825a`, and the MCP exposure discipline it turned on `litrev-mcp`.

### The memory

The global baseline governs the memory write.
Two things it cannot derive: the file is `project_<tool>_evaluation.md`, and the revisit trigger is its own paragraph above the **Why** line, which is where the recorded instances put it, the **How to apply** line carrying what to do instead of the tool.

## The adopt branch

The one recorded instance is the `pdf-inspector` pass, whose split verdict adopted two binaries and decided that neither needed a dedicated updater.
Three lines:

- the install command, and what it writes, from step 4;
- the revert path from step 5;
- the updater, per `rules/install.md`: a tool that enters is covered by an existing `sys-update` module, which `sys-update --list` is the authority for, gets a `<tool>-update` script wired as one, or carries an explicit decision that it needs none, which is what `pdf-inspector-reco.md` recorded when the `cargo` module already covered it.

## What "done" means

- The entry check ran, and either found no earlier verdict or cited the one it found.
- Step 2 named what is actually installed, resolved through `readlink -f`, and the corpus the verdict rests on, or the cost that stands in for one.
- Every verdict-carrying claim was read at its source, and every headline number carries its corpus and its baseline.
- The harness collision is priced, or the candidate is stated not to touch the harness.
- The trial was proposed with its containment conditions and run by the user, or the reading settled the question and no trial was proposed.
- The verdict names a revisit trigger that could be recognised when it lands, and a revert path.
- The note exists at `_meta/notes/<tool>-reco.md`, and the concepts worth transplanting are named.
- Nothing was installed, and every file written is one this pass prescribes: the note, the memory entry, a stopped gate's backlog row, or what a transplanted concept changed.
