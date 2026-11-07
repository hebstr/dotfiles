# DESIGN-CADRER.md

Design note for the skill `design` (`claude/.claude/skills/design/SKILL.md`), called `cadrer` until its rename on 2026-09-24; the sections dated 2026-09-24 and earlier predate the rename and name it `cadrer`.

## The skill becomes `design`, rewritten in English

Decision (validated by the user on 2026-09-24, implemented the same day): the skill is renamed `design` and its text is translated into English.

What a translation of the remaining skills must deliver is idiomatic English that keeps each rule's meaning, never a word-for-word rendering; a fidelity review checks both.
The first translation (`435a54c`) was a calque the user rejected, so follow the retranslation (`d189ca8`) for the text as it stands; the four faux amis it fixed are in `feedback_fr_to_en_translation.md`.

The name's one real cost is that a personal skill replaces the bundled, policy-gated `/design` command ("Make a new Design artifact from a brief", present in Claude Code 2.1.281; precedence per the "Skills" doc page, "Your skill replaces the bundled command"); no transcript shows the user ever typed it.

Rejected names:

- `frame`: a literal translation the user found flat.
- `decide`: describes the outcome, but the skill recommends and the user decides; the user was not convinced.
- `plan`: a built-in command.
- `scope`: overloaded in `CLAUDE.md`.
- `brainstorm`: the best-known community name (obra/superpowers), but it connotes divergent ideation where the skill converges on one recommendation.
- `tradeoffs`, `adr`, `shape`, `approach`, `weigh`: names the method or the record rather than the act, or a vocabulary (Shape Up) less known than design docs.

The opening line "Conduct the conversation in the user's language, whatever the language of this text."
was added rather than translated, no French source having carried it, and the risk it covers was measured on 2026-09-24 over 31 past loads of English skills (`workflow:*`, `audit:*`, `ref`): 27 replies in French, the one English reply in a French conversation being `/workflow:write` on the English `README.md`; word-count language detection, so indicative.
The old name stays wherever it is record, with one class of exception: a replayable check must name the live skill, which is why the skill-discovery check of `_meta/notes/opencode-harness-setup.md` was updated to `design`, `showboat verify` being bound to fail on it otherwise.

Deferred, one pass each: the French skills meant for Claude move to English at their next substantial rewrite rather than in a translation campaign.
Left, in this order: `relire`, then `zotero`; the two done are `commit` and `depouiller`, whose fidelity reviews are in `feedback_fr_to_en_translation.md`.
**A finished pass can still leave French behind, measured on `review-comments` on 2026-10-26**: its translation of 2026-09-29 had kept the register's labels and verdict strings as quoted literals, and the user ruled that day that a skill's own text carries no French at all, whatever a string's role in the artefact. The standard the two remaining passes apply is therefore that the skill names its artefact's fields in English and points at the script or at the artefact for the exact strings, the script going on writing the deliverable in the user's language; a tally or a check that greps those strings names where they are read off rather than retyping them translated, which is the defect `feedback_fr_to_en_translation.md` already records.
The `.claude/` notes left that rule on 2026-10-16 and are finished as a campaign instead, in the section below.
The campaign gives `PLAN-SESSION-DISCIPLINE.md` and `DESIGN-COMMIT-GUARD.md` a pass each like the rest, and places them last because other files quote their headings; `DESIGN-COMMIT-GUARD.md` took the French of its commit-guard half on 2026-10-15 under that same constraint, the split having repointed those headings rather than rewriting them.

Decision (validated by the user on 2026-09-24, applied in the fidelity-review conversation of the `commit` translation): the report of `skills/commit/agents/verifier.md` moves to English (`Findings`, `Greps`, `Out of scope`, `No findings.`, "no match", "not applicable"), because its only reader is the main session, which relays it in the user's language, and no hook or script parses its headings.

## The six French `.claude/` notes are finished as a campaign (decided 2026-10-16)

**Decision.** The six notes that still carry French go to English one note per pass, in the order below, rather than waiting for each one's next substantial rewrite.
That withdraws the opportunistic rule above for the notes and leaves it in force for the skills: a note is read on demand and can go a year without a rewrite, and the prune campaign closed around this debt without moving it, the three French notes it pruned on 2026-10-14 coming out of that pass still French.
Out of scope, the same day: the `relire` and `zotero` skills, which keep the rule above, the 31 files of `_meta/notes/` that carry French, about 1,500 accented lines, and every other project's `.claude/`.

Register, recounted 2026-10-16 with `rg -c '[àâäéèêëîïôöùûüçœÀÂÄÉÈÊËÎÏÔÖÙÛÜÇŒ]'` for the accented lines, the French headings being read off `rg '^#{2,6} '` rather than counted by `rg -c '^#{2,6} .*[àâäéèêëîïôöùûüçœÀÂÄÉÈÊËÎÏÔÖÙÛÜÇŒ]'`, which proved a floor.
The uppercase half of that class is load-bearing: a first reading left it out and under-read `PLAN-SESSION-DISCIPLINE.md` by one heading and `TRIAGE-MEMORY.md` by one, « Étapes », « État local mesuré » and « Élagages de corps » being the shape it misses.
**The accented-heading count is a floor rather than the number of French headings**, found on 2026-10-16 in the first pass: an unaccented French heading is invisible to it, « Revue adverse » and « Preset : pourquoi `default`, et pas `strict` » being the two it missed in `PLAN-PYREFLY.md`, which the register read as carrying none.
The `FR headings` column is therefore the count of French headings read off `rg '^#{2,6} '`, four rows of six having been undercounted, and a pass lists its own headings that way rather than through the accent class, which detects accented lines and nothing else.
Recount rather than carrying these figures, which move with any session that touches a note:

```
| Note                       | Accented / total lines | FR headings | Inbound citers | Pass            |
|----------------------------|------------------------|-------------|----------------|-----------------|
| PLAN-PYREFLY.md            |   0 / 18               |  0          | 2, repointed   | done 2026-10-16 |
| ANTI-SYCOPHANCY-PLAN.md    |   0 / 119              |  0          | 1, repointed   | done 2026-10-16 |
| RECO-SESSION-DISCIPLINE.md |   0 / 115              |  0          | none           | done 2026-10-16 |
| TRIAGE-MEMORY.md           |   1 / 281              |  0          | 4, repointed   | done 2026-10-16 |
| PLAN-SESSION-DISCIPLINE.md |   7 / 485              |  0          | 19, repointed  | done 2026-10-16 |
| DESIGN-COMMIT-GUARD.md     |   1 / 858              |  0          | 19, repointed  | done 2026-10-16 |
```

**The campaign is closed, the six rows done on 2026-10-16.** This register stops being a live tracker with pass 5: it is the record of what the six passes renamed and repointed, and nothing here is a next step.
The last row reads 858 lines and not the 867 pass 5 migrated, the same day's closure having dropped one executed open point from it, the `write-journal.sh` adversarial review that ran clean on 2026-10-11; `PRUNE-OBSERVATIONS.md` keeps 867 in its `Lines` column, which is the figure as of a row's last prune pass rather than a live count, as the 495 of `PLAN-SESSION-DISCIPLINE.md` against its 485 lines already showed.
Out of scope the day it opened and still open: the `relire` and `zotero` skills, which keep the opportunistic rule of `rules/claude-files.md` § Language, and the 31 files of `_meta/notes/` carrying about 1,500 accented lines.

The first pass took the two notes nothing cited by heading, and both turned out to be cited: `PLAN-PYREFLY.md` § « Revue adverse » twice and `ANTI-SYCOPHANCY-PLAN.md` § « 0. Ancrage sur vérité exécutable » once, all three in live text and all three repointed in the same edits.
Both rows had been derived as "none" from the accented headings alone, which is the miss the paragraph above records.

The order is increasing coupling rather than size, which is why the smallest-first reading it resembles is not the reason: the first three were taken for notes renaming only headings nothing else cites, and the last three carry the repoints a rename cannot avoid.
The first half of that reading fell on 2026-10-16, the first pass finding three live citers where the register had none, so the order holds on the volume of repointing rather than on its absence.

The inbound citers, derived 2026-10-16 and to be re-derived after each rename:
`TRIAGE-MEMORY.md` went to English in pass 3, its six headings renamed and their four live citers repointed in the same edits: "Index lines too long" for « Lignes d'index trop longues », cited by `claude/.claude/rules/memory.md` § "One store", by `DESIGN-INSTRUCTION-ROUTING.md` and by the memory-triage status paragraph of `PLAN-SESSION-DISCIPLINE.md`, and "Body prunes of the third pass" for « Élagages de corps », cited by that note's open-task bullet on the eight unparsing frontmatters.
Its four other headings had no citer outside itself, § « Corrections de faits », now "Fact corrections", being cited by its own § "Batch 3: the severity family, its own batch".
"Body prunes" alone would have collided with the note's own § "Batch 2: body prunes outside the severity family", which is why that rename carries the pass it belongs to, and « Élagages de corps » stays named above as the record of what the accent class misses rather than as a pointer.
The undercount showed a third time, on an English heading this time: the note's own head gave "Fourth pass: the sweep under the admission criterion" two citers and named `rules/memory.md` among them, where `DESIGN-INSTRUCTION-ROUTING.md`, `PLAN-SESSION-DISCIPLINE.md` and `PRUNE-OBSERVATIONS.md` cite it and `rules/memory.md` does not.
That row kept four accented lines until pass 4 renamed § « Troisième passe » and repointed its three pointers; the one left points at § « État au 2026-09-09 » and § « Décision » of `_meta/notes/ubuntu-26-04-migration-reco.md`, which the campaign puts out of scope.
`PLAN-SESSION-DISCIPLINE.md` went to English in pass 4, its 24 French headings renamed and 19 pointers repointed over six files: three in `RECO-SESSION-DISCIPLINE.md` ("Steps", "Sequence chosen", "Framing of step 3"), three in `TRIAGE-MEMORY.md` and one in `DESIGN-INSTRUCTION-ROUTING.md` for "Third pass", two more in that file for "Open points" and the bullet "Shell search toward a hook", one each in `PRUNE-OBSERVATIONS.md` and `RECO-CLAUDE-MD-ARCHITECTURE.md`, and eight in `DESIGN-COMMIT-GUARD.md`, whose French prose now quotes English headings.
Three pointers were left as record, all naming the core section as it stood before the split of 2026-10-15: the head of `DESIGN-COMMIT-GUARD.md`, which states the name it had, and the two dated measurements of `PRUNE-OBSERVATIONS.md` that size « Implémentation du noyau » at 724 lines.
**The map overcounts as well as undercounts**, found on the same heading: it placed two of those citations in `DESIGN-INSTRUCTION-ROUTING.md`, where `rg -uu -F` finds the name nowhere, so a row's citers are derived rather than carried in either direction.
**Three of the nineteen point at a bold bullet rather than at a heading** (« La skill seule, sans hook » of the rejected list of step 3, "Scripts de mesure" and "Recherche shell vers un hook" of the open points), which a derivation over headings alone never surfaces: pass 5 derived over the bullet labels its renames touch too, and that derivation is what found the `DEFERRED.md` citation of the session-id rotation bullet, now "Session id rotation", the one external pointer of pass 5 that aims at a bullet rather than a heading; its French name is left unquoted here so that it stays a record rather than a pointer.
The collision shape hit pass 4 once: § « Voies écartées » became "Rejected ways" rather than "Rejected", which the note's own `**Rejected.**` labels already carry, so the pointer of `DESIGN-COMMIT-GUARD.md` still resolves to one place.
`DESIGN-COMMIT-GUARD.md` went to English in pass 5, its seven French headings renamed ("Verifier and stamp", "Gate", "The `commit` skill", "The shell of the `commit` skill moves into tested scripts", "The `commit` skill moves to a separate plugin with its gate and its journal, once the mechanism is stable", "Known limits of the journal", "Open points") and 19 pointer sites repointed over three files: 16 inside the note itself, two in `PLAN-SESSION-DISCIPLINE.md` (the « Porte » bullet and the two long section names of its migration bullet) and one in the `SessionEnd` entry of `DEFERRED.md`, which cites two names at once.
Seven bullet labels and quoted fragments were renamed with them, each carrying a live citer: "the gate unites the journal and `git status`", "`ctime` instead of `mtime`", "the loop guard is specific to the gate", "Rewriting the stamp at 0.1.4", "Session id rotation", "First red test: an unreadable stamp or journal must exit with an error, never with an empty list" and "that the gate and step 0.1.4 both call".
Those three unaccented headings were read as absent until 2026-10-16, so a row's citers are derived over all its French headings rather than over the accented ones.
**§ « Skill `commit` » was settled as a French heading** and renamed "The `commit` skill", so the count was 7 and not 6: that note uses « skill » as a French feminine noun throughout (« la skill `commit` », « La skill sans la porte »), which makes the heading an elliptical « La skill `commit` », no other heading of the note is a bare type label, and the note's own English prose writes "The `commit` skill".
It had no citer anywhere, so the rename repointed nothing.
Two candidate names were measured for collision before being settled, as pass 3 and pass 4 prescribe: `rg -uu -F '"Gate"'` matched nothing in the corpus, the note's own `Gate B`, `Gate C` and "Gate, approach A" labels not carrying the quoted form, and "The `commit` skill" collides with one line of ordinary prose inside the note while its quoted form resolves to one place.
`skills/commit/agents/verifier.md` names "Points ouverts" among the live-passage headings its section 5 matches, beside "Next" and "Blockers", and **renaming that heading in the last two notes left that list alone**, which pass 4 first recorded the other way round.
Pass 4 added "Open points" beside the French string rather than swapping it, and the French string stays for good: section 5 matches the notes of whatever repository the verifier runs on, and five `## Points ouverts` headings sit in the French notes of `md-nesrine` and `eds-prise`, which no pass of this campaign touches.
Re-derived by pass 5 before it trusted that (`rg -n --hidden -uu -g '*.md' '^#{1,6} .*Points ouverts' ~/Documents ~/dotfiles`, 2026-10-16): the same five outside this corpus, two in `md-nesrine` and three in `eds-prise`, and one inside it, the last of the six, now renamed.
So pass 5 touched no file of the parent repository and committed in `.claude` alone: a heading list inside a mechanism is scoped to every repository the mechanism runs on, never to the corpus a campaign is migrating.
Nothing in `~/.claude/memory/` cites a heading of the six, and nothing in `_meta/notes/` does either.
`RECO-SESSION-DISCIPLINE.md` § « État local mesuré le 2026-09-22 » became § "Local state measured on 2026-09-22" in pass 2 with no citer to repoint, and the § « État local mesuré » of `_meta/notes/zotero-agent-access-reco.md` that the Zotero rollback entry of `DEFERRED.md` cites was left untouched: `refs-lint.py` reports 0 dangling on both files after the rename, that note now holding the name alone.
Its row kept three accented lines because a migrated note still points at French headings: § « Étapes », § « Séquence retenue » and § « Cadrage de l'étape 3 » of `PLAN-SESSION-DISCIPLINE.md`, quoted as they stood on disk until that note took its own pass, so **an accented-line count of a done row is a floor on the pointers it owes, not unfinished migration**.
Pass 4 renamed those three targets and cleared the row to zero, as it took `TRIAGE-MEMORY.md` from four accented lines to one, which is what that floor predicts: the nine the `PLAN-SESSION-DISCIPLINE.md` row kept were its own verbatim French quotations plus the two pointers it owed `DESIGN-COMMIT-GUARD.md`, and pass 5 repointed those two, leaving the seven quotations the row shows now.
The `DESIGN-COMMIT-GUARD.md` row keeps one accented line for the same reason read the other way: it is the record of the name the core section had before the split of 2026-10-15, one of the three pointers pass 4 left French, and its two siblings in `PRUNE-OBSERVATIONS.md` keep the guillemets too, so pass 5 left it byte-identical rather than translating a name the tree never carried in English.
Deriving this map needs `rg -uu` from `~/dotfiles/.claude` and `rg --hidden -uu` from `~/dotfiles`, that directory being both hidden and gitignored in the parent, and `_meta/session-discipline/*.json` excluded since the transcript shards match every heading.
A heading too short to be distinctive (« Porte » and « Points ouverts », the two `DESIGN-COMMIT-GUARD.md` carried until pass 5, and « Limites » and « Objectif » before pass 4 renamed them) is searched through its quoted forms, `"Porte"`, `« Porte »` and `§ Porte`, the bare name matching ordinary prose everywhere.
The rule survives the renames: "Gate" and "Open points" are short in the same way, so they are cited and searched in their quoted form, which is what made the seven self-citations of "Gate" countable.
One measured consequence, 2026-10-16: `refs-lint.py` went from 38 tested references to 36 on that note at 0 dangling throughout, and **that net of two is the sum of three movements**, derived by replaying its `CUE` and `SPAN` pair over the `HEAD` blob and the migrated file rather than read off the counts.
It tests a quoted name of 12 to 120 characters preceded by a cue word (`voir|see|section|sous|under|puce|bullet|décision|decision|of`).
The two citations of « Points ouverts » (14 characters) stopped being tested once renamed "Open points" (11), which is the only loss a rename caused; the pointer at the `CLAUDE.md` section « Claude Code plugin/skill repos », which no longer exists there, stopped being tested when it was repointed at an unquoted name; and the fourth citation of the shell section gained a test, French « la revue des scripts de « … » » carrying no cue word where English "the review of the scripts of" carries `of`.
So a rename can take a name out of the linter's reach, a repoint can remove a test altogether, and a count read alone attributes the whole move to whichever cause comes to mind first.

A pass translates and never prunes: the reserve of `rules/claude-files.md` § Content is carried over in English rather than cut, and the standard is the migration case of `feedback_fr_to_en_translation`, fidelity to each rule line by line.

## `depouiller` becomes `review-comments`, translated in the same pass (2026-09-29)

Name: four candidates were put up, `adjudicate` (recommended), `respond`, `review-comments` and `triage`, and the user picked `review-comments`.
No bundled command collides with any of them: the strings of the 2.1.284 binary carry no `name:"<candidate>"` declaration, the form in which the bundled `/design` declares itself, so the check is bounded to commands declared that way.
`triage` was argued against because the skill's own stage 2 is the triage, so the name would cover one stage out of three.

Left open by the fidelity review of 2026-09-29, checked and deliberately not flagged: `startswith("non")` and `("ambigu")` couple the English summary to `locate()`'s French output, a coupling that predates the pass.
`chantier` was weighed the same way and kept, already established in this repo's English notes (`DESIGN-SSH.md`, `DESIGN-WINDOWS.md`, `DEFERRED.md`, this note).

## Four targeted corrections to the skill text, nothing else

Decision (validated by the user on 2026-09-24, implemented the same day): the `design` skill keeps its structure and gains four corrections, each aimed at a defect seen in at least two of the three audit batches.

- **B1, dead references and a narrow entry search.** "la table des chantiers de `PLAN.md`" becomes the chantier's plan file (`PLAN*.md`); the pointer to a project section « Références au code dans les notes » becomes the global rule "Cite by name, never by line number" of `CLAUDE.md`; the entry grep for an existing decision widens from `PLAN.md` and `.claude/DESIGN-*.md` to `.claude/*.md` and `_meta/notes/`.
- **B2, step 1.** An indeterminate that a read or a read-only command settles is settled in step 2, never carried as a hypothesis.
- **B3, step 4.** The most fragile hypothesis is tested before the recommendation whenever a side-effect-free test exists (scratchpad, read-only command); otherwise it is declared untested.
  A probe with side effects (processes, a remote machine) is asked for first.
- **B4, validation.** The validation question names the voie and separates every bundled decision; the closing message ends on the recommended next step, and agreement to that step is the new instruction.

## The audit behind it

Corpus: 25 invocations from 2026-09-18 to 2026-09-23 across four projects (dotfiles, md-nesrine, quarto-hebstr-doc, claude-code-plugins), eleven under the version before `790d114`, read in three batches by sub-agents over transcripts condensed from `~/.claude/projects/`.
The relevé matched `<command-name>/cadrer</command-name>` only, which is what left the seven invocations recorded as unread in "Open"; the three batches converged, so the corpus was not extended.

What holds and is left untouched:

- Step 2 carries the most value: it found the `bslib` code-font key for R-edstr's pkgdown fonts, the prior decision in `DESIGN-AGENT-SKILLS.md`, and overturned the model's own sshd recommendation.
- The stop at validation holds: no code before validation under the current version; the two slips (note and code validated together, a detail answer taken as a go) predate it.
- The entry exits apply (Zotero sent to `/workflow:reco`, the hebstr-doc entry check spoken aloud), with one miss: the second Positron framing re-ran a full cadrage on a decision already taken in the conversation.
- No complaint about length or tone; proposals ran 4 000 to 10 000 characters.

Defects the corrections target:

- Recommendations resting on unverified claims, about nine cases in three batches (B3, B2): the Positron filter claimed to clear `git status` and did not, found after the commit; two code-window premises fell during implementation; "qwen3.8" read as Qwen3 8B and copied into a note three times; a partial read of `DESIGN-GPU-REMOTE.md` recommended a voie that note already rejected.
  The one fragile hypothesis tested before deciding, the Zotero local API port, held.
- The blocking-ambiguity rule never fires (B2): "aucun ne bloque" almost every time, `zotero-update` labelled a point blocking and proposed anyway, the sshd framing wrote "dis-le et la conclusion change" without asking.
- Dead references and a narrow entry search (B1), checked directly: the dotfiles have no `PLAN.md`, only `PLAN-*.md`; no project among the four has the referenced section; decisions also live in `PLAN-*.md`, `RECO-*.md`, `DEFERRED.md` and `_meta/notes/*-reco.md`.
- Thin validation on long bundled proposals (B4): one "ok" covered three decisions of the session-discipline step 3, one of them a convention reversal; a post-validation "ok" was a go in two sessions and not in a third, which left the user asking where the framing stood.
- Unbounded probes in step 2 (B3): useful when read-only or in the scratchpad, harmful once, when a probe started and killed processes on ju-TP2 and a `pkill` ended its own session.

## Rejected ways

- **Do nothing.** The core holds and `CLAUDE.md` already requires running the verification a recommendation depends on, yet the unverified-claim defect cost a reverted commit and a note wrong in three places under that same global rule.
- **A mechanical check by hook.** A hook cannot tell that a reply belongs to a framing without reading the transcript, whose format is undocumented, the reason `SubagentStop` was rejected in `DESIGN-COMMIT-GUARD.md` (« Vérificateur et tampon »); the targeted defects are judgements, not patterns.
- **Rewriting or condensing the skill.** No complaint about length, and the step that works best is the most detailed one.
- **Tightening the exits.** Off-core uses (feasibility, audit method, memory cleanup) went well, and the pkgdown framing that a "bug à corriger" exit would drop is the one that found the fix.

## Open

- Whether a placement next to the need changes behaviour where the equivalent global rule did not.
  If later framings still recommend on untested claims, the lever becomes the `commit` verifier, which already corrects notes after the fact.
- "Do nothing" is dismissed in one line, without its cost and without the prohibition: the skill's text is clear, so the drift is execution rather than wording.
- The seven invocations loaded through the `Skill` tool remain unread.
- Step 4 of `PLAN-SESSION-DISCIPLINE.md` has one count to account for on framed sessions: "Measured baseline" records reversals that follow a verification made only when the user asked again, which B3 moves before the first recommendation.
- **How many prompt buffers a project may hold.** `rules/claude-files.md` allows one, `.claude/PROMPT.md`, and since 2026-10-17 `ls .claude/PROMPT*.md` returns that file alone, so the question has no live instance: what stays open is whether a named buffer per chantier is a second pattern to sanction or a drift to fold back into the one file.
  Two facts of 2026-10-02 bear on it without settling it: `PROMPT-PDF-TABLES-EVAL.md` was deleted as a consumed buffer, which says the pattern's real cost is a buffer outliving its chantier rather than its name; and `PROMPT*.md` is now gitignored in every `.claude` repository, so the pattern no longer puts anything in git whatever is decided.
  The deletion rule has fired four times, on that buffer, on `PROMPT-POC.md` (written 2026-10-08 and deleted the day the `poc` skill it carried was built), on `PROMPT-PRUNE.md` (written 2026-10-01, deleted 2026-10-13 as a superseded handover every rule of which had another holder) and on `PROMPT-SYSCLEANUP.md` (naming the `sys-cleanup` framing brief by 2026-10-06, emptied by the user on 2026-10-16 when they cut it into the `/design` pass that decided it, deleted on their instruction the next day), so a named buffer whose own text names its deletion condition does not outlive its chantier.
