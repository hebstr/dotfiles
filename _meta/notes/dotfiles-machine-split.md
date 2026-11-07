# One stow package per divergence, never a machine registry

Decision taken on 2026-11-07, extending the Positron split of `_meta/notes/positron-stow-split-reco.md` to every file that diverges between `ju-TP` and `cpd`, `.bashrc` and `.blerc` first.

## The decision

A file that differs between machines is carried by one stow package per machine, named after the application plus a suffix that names the machine or profile: `bash` and `bash-cpd`, `positron-hebstr` and `positron-edjulien`.
Each package is self-sufficient for its target path: `bash-cpd/.bashrc` stands alone, it does not assume `bash/` is stowed alongside.
The machine never gets a registry package: there is no `cpd/` package holding everything cpd-specific.

## Why

The repository precedent for a diverging configuration file is one package per divergence, not per host: `cpd/` exists but carries a single server script, not a registry of diverging files.
`firefox` and `zotero` are tied to one machine each yet carry the application name, and `_meta/notes/dotfiles-bootstrap.md` lists them as ordinary packages in its structure block and bootstrap line, where `cpd` is absent because it is stowed only on the workstation.
`positron-stow-split-reco.md` measured the grouped layout and rejected it: grouping under a shared directory forces moving the stow directory, breaks the repository's single `stow -t ~ <list>` invocation, and pollutes `$HOME` at the first reflex, since `stow -t ~ positron` would plan `MKDIR` for each subdirectory with exit 0.
A machine registry is the same trap one level up: `stow -t ~ cpd` from the root works once, but the moment a shared package and the registry both claim a path, or the habitual line names the wrong one, the failure is silent directories, not an error.

## Rejected

A single `cpd/` package holding every diverging file.
It fragments one coherent file across two packages that share a target: on `cpd`, `bash/.bashrc` and `cpd/.bashrc` both resolve to `~/.bashrc`, so either stow refuses or the shared package must drop the file, which defeats sharing the parts that do not diverge.
It also inverts the naming precedent: the suffix would name the host while the bare name names the application, the exact confusion `positron-stow-split-reco.md` ruled out for a `positron` plus `positron-cpd` pair.

A shared package plus an unversioned local file (`~/.bashrc.local`) for the deltas.
It keeps one versioned file but takes the divergence out of git and out of Syncthing, against the repository's stated goal that a fresh machine be rebuilt from the clone alone.

## Open

Settled on 2026-11-07 from a diff run on `cpd000001`: `.bashrc`, `.profile` and `.bash_logout` all diverge, so all three entered `bash-cpd/` in full; `.blerc` is absent on that machine and stays out.
The split was built as one package per divergence with no shared-content trimming of `bash/`: `bash/` keeps the main machine's files untouched, and `bash-cpd/` carries the workstation's files as they stand, so a file edited on one machine reaches the other only through a deliberate copy.

Whether, when the split of `positron-stow-split-reco.md` is built, the `positron-theme` clean filter covers both packages through one glob, per the open arbitration there.
It is restated here only because a new machine-specific package makes the question load-bearing for every future split.

## When it is built

Done on 2026-11-07: `_meta/notes/dotfiles-bootstrap.md` gained `bash-cpd` in its structure block and its bootstrap line, a one-line stow order for the workstation, and a per-package caveat mirroring the `firefox` one: the package is machine-specific by name, so stowing it elsewhere links where nothing reads it.
