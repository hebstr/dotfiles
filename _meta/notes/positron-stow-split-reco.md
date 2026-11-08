# Stowing a second machine's Positron settings

Recommendation written on 2026-11-06, for making the `cpd` workstation's Positron `settings.json` stow-managed alongside `ju-TP`'s.
**Superseded on 2026-11-08: `cpd`'s live settings live in `~/.positron-server/data/Machine/settings.json` (Positron runs there as a remote server), and the `positron-cpd` package stows that file alone; nothing was renamed, so the two-package split below never happened.**
The note keeps the measurements that still bind: the profile-directory caveat, the drift guard, and why the grouped layout was rejected.

## The two files never share a target path

There is no stow conflict to solve, because the profile directory is an opaque per-machine identifier.
On `ju-TP` it is `~/.config/Positron/User/profiles/-eb36ac2/`, for the profile registered as `hebstr-positron` in `globalStorage/storage.json`.
That identifier is not derivable from the profile name: VS Code's `stringHash` of `hebstr-positron` computes to `-8e49436`, against the `-eb36ac2` on disk.

Two consequences, in opposite directions.
One stowed file can never serve both machines, so the divergence has to be carried by two files whatever the packaging.
And a profile deleted and recreated takes a new identifier, so the link lands where Positron never reads: the same caveat `dotfiles-bootstrap.md` records for `firefox` and `zotero`, and the reason the identifier is read on the machine rather than reconstructed.

## Recommended: two sibling packages

`positron-hebstr` and `positron-edjulien`, named after the profiles rather than the hosts: the profile is what makes the path diverge, and the names match those of `_meta/profiles/hebstr-positron.code-profile` and `edjulien-positron.code-profile`.
The `positron-` prefix keeps the two adjacent in a listing and in the stow line.
Renaming both, rather than keeping `positron` on one side, is deliberate: a `positron` plus `positron-cpd` pair hides which machine the bare name means.

The order below matters, the live links holding `dotfiles/positron` relatively:

```sh
cd ~/dotfiles
stow -D -t ~ positron
git mv positron positron-hebstr
stow -R --no-folding -t ~ positron-hebstr
```

The glob lives in the repository's root `.gitattributes`, whose only line is `positron/.config/Positron/User/profiles/*/settings.json filter=positron-theme`, and becomes `positron-hebstr/.config/...` or a `positron-*` form covering both packages, per the arbitration below.
No hook or script enumerates the stow packages: `symlinks-check` walks the links of `$HOME`, and `prek.toml` carries no `positron` pattern, so a new package needs no registration anywhere.

## Why the grouped layout was rejected

`positron/{hebstr,edjulien}/` was the user's own second idea, and it was measured rather than argued.

Stow imposes no depth limit: a package with 25 nested levels stows cleanly.
What is constrained is the first level, not the depth.
The first directory under the stow directory is the package name, and everything below it is interpreted as relative to the target.

So grouping requires moving the stow directory, `stow --no-folding -d positron -t ~ hebstr`, which is a separate invocation from the repository's single `-t ~ <list>` line.
The trap is what the habitual line then does: `stow --no-folding -t ~ positron` plans `MKDIR: hebstr`, `MKDIR: edjulien` and links the settings under `~/hebstr/...`, with no error and exit 0.
Two junk directories in `$HOME`, and not one active setting.
A `.stow` marker inside `positron/` does not prevent it: the `MKDIR` is still planned, that marker protecting a stow directory from another stow directory's operations rather than keeping a package from being walked.
`stow -D positron` from the root answers `hebstr did not exist to be unstowed`.
A `.stowrc` inside `positron/` carrying `--dir` and `--target` does work, but only from that working directory, and the repository has no `.stowrc` today.

The cost of grouping is therefore not depth, which is free, but a singular invocation plus a polluted `$HOME` at the first reflex.

## What diverges, and the drift guard

Of the 777 lines stowed for `ju-TP`, six keys are machine-specific: `pyrefly.lspPath`, `sqlfluff.executablePath`, `bashIde.shfmt.path`, `positron.r.customBinaries`, `positron.r.interpreters.default` and `workbench.externalBrowser`.
Everything else is portable, and the keys of extensions absent from `cpd` are inert rather than faulty.

`ju-TP` stays the reference, and that list is the whole guard against the two files drifting: a `diff` of them should show nothing outside it.
The `cpd` file is therefore a copy with those keys resolved locally, not a hand-built one.

## Blocker

The `cpd` profile identifier, which only a command run there gives:

```sh
python3 -c "import json;print(json.load(open('/home/edjulien/.config/Positron/User/globalStorage/storage.json'))['userDataProfiles'])"
```

`_meta/profiles/edjulien-positron.code-profile`, exported on 2026-04-30, carries only two settings keys (`files.associations` for `renv.lock`, and `workbench.keybindings.rstudioKeybindings`), so there is almost nothing to preserve on that side.
Whether it was exported on `cpd` at all is unverified from `ju-TP`, where `storage.json` registers one profile only.

## Open arbitrations

Whether the `positron-theme` clean filter covers both packages, through one `positron-*` glob and the same forced `Tomorrow Night` everywhere, or stays on `positron-hebstr` alone.
The filter has no `smudge` half, so a glob covering `cpd` would reset the theme there at every checkout of the file.

Whether the `cpd` package carries `keybindings.json`.
It sits in the same profile directory, so it follows the same split by construction; the only question is whether `cpd` gets a versioned copy or keeps a local file.

## When it is built

Three tracked files name the package and move with it.
`dotfiles-bootstrap.md`, in its package list and in its stow line, and its per-package caveats, which cover `firefox` and `zotero` only today, gain the profile-identifier caveat above.
`wsl-init-tuto.md`, in the single package-table row listing `positron` among the applications stowed nowhere, and in the prose bullet stating that the package is not stowed under WSL.
The root `.gitattributes`, whose one line carries the `positron-theme` filter.
`opencode-cpd-setup.md` names no Positron package, so it does not move.
