# DESIGN-POC.md

Design note for `poc`, the pass deciding whether a candidate tool enters this setup.
Decided 2026-10-08 and built the same day at `claude/.claude/skills/poc/SKILL.md`, stowed as a single directory link.

The user approved seven items separately that day: six are the sections named after them below, and the seventh split the note, `DESIGN-AGENT-SKILLS.md` holding the placement criterion.

## The pass becomes a user-level skill, the marketplace being closed to it

The placement applies a criterion this file does not own: `DESIGN-AGENT-SKILLS.md`, section "Where a skill the user writes goes is decided by its coupling to this machine", holds the ruling and the search for markers of this machine that established it, because it governs every skill written here and not this one.
What puts `poc` on the user-level side of that line is that the steps carrying its verdict read this machine's stack, its installed binaries and its hook surface.

The name `poc` is kept.
`eval` was dropped as overloaded (shell builtin, model evaluation) and `adopt` as presupposing the outcome, which contradicts a rejection being a first-class verdict.

## The pass had an output convention and no procedure, which is the gap the skill fills

The `*-reco.md` family of `_meta/notes/` makes the artifact of this pass conventional already, `pdf-inspector-reco.md` being its fullest form.
The convention is not self-enforcing.
gortex, the most recent and most fully traced instance (2026-10-07), produced no `_meta/notes/` note at all, only a memory entry, since merged into the "gortex" section of `project_closed_tool_evaluations.md`.
A procedure is what the convention was missing, not a shape.

## Six steps, the seven of the proposal having one fusion

The six are the skill's own numbered sections, from the forge state to the persistence of the note.

The proposal's two separate steps fused into "Verify every verdict-carrying claim at its source" because the practice is one practice, reading instead of trusting, and the "gortex" section of `project_closed_tool_evaluations.md` already holds both of its findings in a single paragraph.
Keeping them apart would be bookkeeping.

The build of 2026-10-08 added one thing the seven items do not name, the entry check titled "Before step 1: check the verdict does not already exist", which cites any earlier verdict it finds and asks whether the invocation reopens it.
It is not a seventh step and it changes no step; its shape is the first exit of `design/SKILL.md`, "the decision already exists".

## The contained trial is a gate the skill proposes and the user runs

Two reasons, the second of which binds where the gate may sit.
`.claude/DEFERRED.md` assigns the PoC to the user in its cloudflared entry, which is the local precedent.
And the gate comes after all the reading, so "never install in order to evaluate when reading settles it" is enforced by position rather than by a reminder the skill would have to repeat.

## The skill writes the note and leaves the memory to the baseline

The memory write is already bound by the global baseline, so the skill does not restate it, mirroring how `design/SKILL.md` ends at its note and routes the gate and the plan entry to its section "What comes after, and is not this skill's job".

Settled at the build, 2026-10-08, on the open point that the shape lived twice: the skill's fenced English template is the authority, and `pdf-inspector-reco.md` is cited as the fullest worked instance of the pass rather than as the source of the headings.
This removes the second authority instead of adding a drift check between two, which could never have compared anything anyway: the existing family is French and its translation deferred by `rules/claude-files.md` to each note's next substantial rewrite.

## The adopt branch stays three lines until an adoption gives it a precedent

Most recorded instances ended in a rejection or a deferral, and the one that adopted, `pdf-inspector`, predates this skill, so the adopt path has no instance that ran through it and a long branch would be invention.
Only its third line decides anything, and it decides it elsewhere: the updater question is `rules/install.md` applied rather than settled here.

## The scope excludes acquisitions, hardware and OS upgrades

`sas-install-reco.md` turns on licensing and price, `ubuntu-26-04-migration-reco.md` on a release calendar, `ssd-externe-kingston-reco.md` on hardware.
The machine-state, verification and collision steps have nothing to bite on in any of the three, so folding them in would add a branch that reduces to the note template, which is why they keep the `_meta/notes/<subject>-reco.md` convention without the procedure.

## Approaches rejected, with what disqualified each

- **A marketplace command, `workflow:poc`.** The two steps that carry the verdict would have to discover the environment instead of knowing it, roughly the work of the runtime reviewer scan that `walkthrough` and `blindspot` delegate to `scan-reviewers.py`, and a published skill then owes CI, a README row and a CHANGELOG entry.
  Naming the occupied hook events and the replicated `settings.json` directly is what keeps "Price the harness collision" cheap enough to run.
- **Do nothing: `/workflow:reco`, the `-reco.md` convention and the baseline's "Test the premise before building".** The Step 2 scope check of `workflow/reco/SKILL.md` stops on a purely local question, and the deciding steps here are purely local, so reco routes away from this pass by design.
  The convention alone did not fire on gortex.
- **A note template only, the pass staying manual.** Same gortex fact: the artifact convention without a procedure produced nothing on the instance that most needed it.

## What the decision rests on, and when it stops holding

This holds as long as a candidate's fate keeps turning on this machine's actual state.
Tested read-only on 2026-10-08 across four instances: gortex on `.qmd` chunk bodies and the absent R language server, arity on `persistent-line-breaks` and the 341 `!!` lines, the YAML gate on a misidentified installed binary, pdf-inspector on measured regressions against the real Zotero corpus.
Four for four, and the YAML case widened the mapping onto this machine's state rather than breaking it: the gate being designed rested on `/usr/local/bin/yamllint`, a symlink to npm's `yaml-lint`, so the facet that decided was a misidentified binary rather than the language stack.

If a candidate arrives whose verdict turns on something stack-neutral, "Map the candidate onto this machine's actual state" degenerates to a formality and the skill reduces to its note template, which is the `sas-install-reco.md` shape and the reason those instances are out of scope.

## Open points

- The whole `*-reco.md` family is in French while the skill will emit English, per `rules/claude-files.md`.
  No pass translates them now: `rules/claude-files.md` defers existing French Claude-facing content to "its next substantial rewrite", and the "Deferred, one pass each" paragraph of `DESIGN-CADRER.md`, section "The skill becomes `design`, rewritten in English", refuses a translation campaign for what still answers to it.
  The six French `.claude/` notes left that rule on 2026-10-16 for a campaign of their own, which `_meta/notes/` is explicitly out of.
  So the family stays mixed-language in fact, French for what exists and English for what `poc` writes.
  `_meta/notes/*.md` entered the language scope of `rules/claude-files.md` on 2026-10-10 (and its `paths:` globs, until the hook became the rule's only delivery on 2026-11-06), so each of the 30 notes of 52 whose French stopwords outnumber their English ones now carries the per-rewrite debt instead of none, and no campaign closes the gap at once.
- Whether the adopt branch stays three lines is unresolved until an adoption actually runs through it.
  `pdf-inspector` is a recorded adoption, `pdf-inspector-install.md` holding its trace, but it predates the skill by seven weeks and so never ran through the branch.
