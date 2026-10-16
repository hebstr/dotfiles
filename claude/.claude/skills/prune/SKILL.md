---
name: prune
description: >
  User-invocable ONLY via `/prune [<note or project>]`.
  Does not auto-trigger on mentions of "clean up the notes", "this plan is too long", "the tracking is stale", "prune", "élaguer les notes", "nettoyer le suivi", "ce plan est trop long", and never on a session closing a step, which the criterion of `rules/claude-files.md` already covers.
  The pass that cuts a project's `.claude/` notes and the decision notes of `_meta/notes/` down to what still binds future work.
  Not for: the memory store, whose admission test and index ceiling are in `rules/memory.md`; `CLAUDE.md` and the unscoped rules files, governed by the routing test and the `instructions-budget` check; `NOTES.md`, `TODO.md` and `CALENDRIER.md`, which are the user's and are never written to; choosing between ways of implementing something (use `/design`).
disable-model-invocation: true
---

# Cutting a tracking note down to what still binds

This skill takes a note, or a project whose notes need an order, and returns cuts the user has arbitrated.
It carries the order of the pass and nothing else.

Three things sit outside it and are never restated here.
The criterion is a rule, in the "Plans and tracking" bullet of the global `CLAUDE.md` and in the "Content" section of `rules/claude-files.md`, both loaded every session.
What the criterion protects is the reserve, in that same "Content" section.
The motifs, 138 of them at the completest grain thirty-six passes reached, are in `~/dotfiles/.claude/PRUNE-OBSERVATIONS.md` § "The motifs of the thirty-six passes": read that section before step 3 on a dense file, and never from recall.

"Nothing left to cut here" is a first-class verdict.
The campaign that produced this procedure ended with most of its rows reading "little left", and a pass that confirms one is a pass that delivered.

Conduct the conversation in the user's language, whatever the language of this text.
A note keeps its own language: a French row owes a prune and then a migration, two passes and not one, under the re-authoring constraint of `DESIGN-CADRER.md`, and the pass says which of the two it is doing.

## What this pass does not write

No per-pass record.
The record was priced in the corpus and it lost: it became the campaign's second-largest grower, at one reading 2.64 times what the passes had removed from every other note, and the reading that closed the register found a further pass adding about 27 lines of record there to remove 8 to 47 from a smaller row.
A pass writes its commit message, which is what the nested `.claude/` repository exists to hold.

Two exceptions, both narrow.
A motif the list in `PRUNE-OBSERVATIONS.md` does not already hold is appended there, that file being the single central corpus whatever repository the pass ran in.
And a dotfiles pass updates the row it touched in that file's table, never the other rows: the `Lines` column is the reading taken when a row was last read and it moves with every session.

The pass creates no per-project corpus, and where one already exists that corpus is the holder and governs the record's shape.
`R-hebstr/.claude/PRUNE-OBSERVATIONS.md`, opened 2026-10-04, is the one instance: 113 lines carrying a corpus table with a `Pass` column, an order decision that diverges from the dotfiles precedent on purpose, three-class per-pass records and a `Rejected ways` section.
The price above was measured on a 208 KB register, so it bounds that register and not a project one of a hundred lines: a pass there updates its row and appends its record in the shape the file already uses.
Where no such corpus exists, `git log` answers whether a note has been passed and the pass adds no file.

## Before step 1: check the note was not just passed

```
git -C <repo>/.claude log --format='%h %ad %s' --date=short -5 -- <note>
```

A `prune` in a recent subject means the row's cheap half is already gone.
Cite that commit, say what it took, and ask whether the invocation wants a second pass: the `Next` column of the campaign's own table reads "little left" on twenty of its rows, so a second pass is worth starting and worth starting with a lower expectation.

The project's `.claude/` is a repository of its own, ignored by the parent (`DESIGN-CLAUDE-REPO.md`).
Where it has none, say so before cutting anything: a deletion is then unrecoverable, and the homing rule of step 4 becomes the only net.

## 1. Inventory, and the user validates it before any cut

The inventory is a deliverable of its own, and no cut happens until the user has taken it.

What it delivers: the notes of the scope in a target order, each with what a pass may touch and what the reserve already protects.
What it must not deliver is a promised share.
An estimate carries no direction: the campaign's passes undershot at 40 % of the lines read, overshot at 216 %, and met the reading in between, so a figure stated as a target is a claim the pass then has to defend.

Three holders an inventory read file by file cannot see, each of which has inverted a verdict:

- a memory recalled by its description, which is routinely the completer copy and which no file-by-file read opens;
- a rules file with a `paths:` front matter, the strongest holder there is, which has emptied three steps of one note at once;
- a ruling held in another row, which protected a third of one file the inventory had read as cuttable.

So the inventory names, per note, which of the three it did not open, and the pass opens them in step 2.

The scope is the `paths:` globs of `rules/claude-files.md` restricted to notes: `<repo>/.claude/*.md` and `<repo>/_meta/notes/*.md`.
A `PROMPT*.md` is a buffer and not a note, and its resting state is empty.

## 2. Take the citation map, per hit

The citation map is the first check and it decides the scope of everything after it.

```
rg -n --hidden --no-ignore -g '!.git' -F -e '<heading or name>' <repo> ~/.claude/memory ~/dotfiles/.claude
```

`--hidden --no-ignore` is load-bearing and the short form is a trap: `rg -u` reduces filtering one level and leaves hidden paths skipped, where `fd -u` is an alias for both, so a `-u` carried over from an `fdfind` call reports no citer while the citers sit under `.claude/`.
Measured in `feedback_rg_misses_gitignored_trackers`, which holds the incidents.

Three rules the campaign paid for.

A map is re-taken per hit and never inherited, not from a handover, not from a brief, not from a map recorded in a note: a recorded citation map is the one thing the artefact motif forbids reusing, and a map counted by file hides hits a per-hit map shows.
A per-hit map is also what answers the homing question of step 4.

A citer does not freeze whatever it points at, and reading the citer is what says which.
A citer naming N kinds of content freezes the shape rather than the text; one that defers to a section for a shape freezes the whole shape; one that names a correction as owed is a cut instruction and not a freeze; and a verbatim citer can license the cut of the very sentence it quotes, the tense being what decides.
An ordinal cited from outside freezes a list's numbering, so an executed step collapses to one line and keeps its number rather than disappearing.

Then sweep the quoted spans, which no check on names reaches:

```
f=<note>; rg -o '"[^"]{12,120}"' "$f" | sed 's/^"//; s/"$//' | sort -u |
  while IFS= read -r s; do
    rg -Fq --hidden --no-ignore -g "!$f" -e "$s" <repo> || printf 'MISS\t%s\n' "$s"
  done | sort
```

`-e` is not optional: without it every span opening on a dash reads as an `rg` flag and comes back a miss, which produced 16 phantom misses on one file.
Read the output sorted and never counted: misses sharing a prefix are a bug in the sweep before they are a finding.

## 3. Cut what the artefact already carries, unattended

Three phases, in this order, because the third depends on the second.
This is the first.

Here the pass decides alone, the artefact being the better copy:

- a passage describing an artefact the repository carries, at any grain from a bullet to a whole section: a script's exit codes, flags, defaults and thresholds, a suite's case names, a config file's own enumeration, a hook's exemption order, an `--help` surface;
- a status block duplicating the steps below it, read to the end first, because one such block hid a unique record with its decision, its two rejected alternatives and its measurement;
- a bullet whose head carries an executed state word and whose body ends on a sha;
- an objective section, a success-criteria block, an executed implementation order, a verification narrative ending in a committed artefact;
- a block whose own header says it is superseded by a section that survives, one line naming what superseded it taking its place;
- a dead pointer, and a residual regrouped under the one item that holds it.

Two inversions to check before each of these, both recorded:

- a script's own comments are part of the artefact, so prose around a self-commenting pair of scripts empties; but the reserve's "a WHY the code cannot carry" also inverts here, and a script comment or a function body can be the holder that releases a WHY the note was keeping;
- a claim that an artefact does *not* state something is a claim to re-verify, like a superlative, and the cut is the repair wherever the artefact settles it.

## 4. Cut the executed, arbitrating with the user

Phase two, and the phase the user owns.

Propose, with the holder named, and let the user decide:

- anything the reserve of `rules/claude-files.md` protects: a walkthrough block, an internal `Rejected` or `Voies écartées` list, a fragile hypothesis, an unclosed residual, a WHY the code cannot carry, a measurement no better copy holds, everything a pending measurement step must still compare;
- which of inlining, repointing or leaving as record repairs a reference the cut breaks, which is the arbitration and not a default;
- a French row's split into a prune then a migration, and the name a split note takes;
- a never-launched review proposal, which goes where the one the user owns stays verbatim.

A holder is read to the end and never credited: of four holders one note credited, three had drifted and the fourth had moved to a stronger file, and of three passages claiming nothing else held them, two were false.

A verified fact with no other holder is moved rather than kept, and the check is one command.
Its destination is a memory recalled by its description, which beats a plan only the verifier reads, or the file whose subject it is, written in that file's language.
The global baseline governs that write; this skill adds nothing to it.

## 5. Merge and delete last

Phase three, conditioned on phase two having run.

A whole-file deletion is reachable: one note went because a rules file was a strict superset of it, down to the rejected tools and the verified facts.
What makes it safe is phase two first: deleting a spent report was conditioned on having inlined a clause for every identifier the plan named without its object.

Deleting a buffer is not a pass and needs no criterion: an empty one is no placeholder, and a full one whose chantier closed is spent, its own deliverables being the evidence.

## 6. After each cut, not at the end of the pass

```
refs-lint.py <note>
```

After every cut, which is what `rules/claude-files.md` prescribes and what two references out of three cuts went through without.
Its five kinds of false positive are catalogued in `PRUNE-OBSERVATIONS.md` § "The check after each cut", read in one glance rather than counted, and its one false negative matters here: a second holder anywhere in the corpus silences the check for a name, so never quote a dangling name outside the file that owns it, take a before and after on the file in place and never on a copy, and read a sudden drop to zero as a second holder rather than as a repair.
A 0 on dangling says the names it tested resolve. It says nothing about a figure, a sha or a superlative.

Then three guards the tool is silent on.

**Count the structure.** An `Edit` whose `old_string` ends at a line's end and whose `new_string` is empty also eats that newline and merges the line with the next, where a one-character replacement does not.
So prefer a non-empty replacement, and count after the edit: `rg -c '^- \['` for a checklist, a column count for a table, `rg -c '^## '` for sections.
Both probes and the incident are in `feedback_note_restructure_guards`.

**Snapshot before a whole-file rewrite.** One `Write` is far cheaper than dozens of exact-match edits and gives up exactly what `Edit` provides, a loud failure on a mismatch: a passage meant to survive can come back altered with nothing failing.
Copy the file aside first, then compare the kept passages character by character and print which are byte-identical.

**Reread the prose the pass wrote.** Every defect a pass makes is there and nowhere else: a replacement sentence widening a claim past the facts, a dead conditional carried forward, an orphaned deixis, determiner, bare flag, bare cardinal, title or count, a definition cut from under a term the surviving frame still uses.
This has paid in every pass since it was first recorded, and no tool reaches any of it.

A figure the pass writes is derived in the command that prints it, never carried from earlier in the session.
A count restated is a count to redo, and a superlative is a count restated.

## The stop rule

Stop when the next candidate is either reserve or costs more edits than lines: ten edits for 600 bytes is where a pass stops.
Cut by block and not by clause.

Stop without a second opinion and without a sweep for one more candidate.
A note whose remaining content is its reserve is finished, and saying so is the verdict.

The two signals that the pass is now adding rather than removing: a replacement frame longer than the block it replaces, and a third file amended to hold what one short line could have said.

## What "done" means

- The entry check ran, and either found no earlier pass or cited the commit it found.
- The inventory was delivered with a target order and no promised share, named the holders it did not open, and the user took it before any cut.
- The citation map was taken per hit with `--hidden --no-ignore`, and the quoted-span sweep ran with `-e`.
- The three phases ran in order, and nothing the reserve protects was cut without the user arbitrating it.
- `refs-lint.py` ran after each cut and not at the end, the structure was counted after any edit that could merge a line, and the prose the pass wrote was reread.
- Every fact the pass cut that had no other holder was moved before it went.
- The pass wrote its commit message, a motif only if the list lacked one, and outside dotfiles nothing else.
