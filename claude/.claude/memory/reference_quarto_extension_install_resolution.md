---
name: Quarto extension install resolution (tag vs GitHub release)
description: What `quarto add <owner>/<repo>` actually downloads: the main-branch tarball for the bare form and for `@latest`, `archive/refs/tags/<tag>.tar.gz` for a pinned one; Quarto never queries the GitHub releases API for an extension, so the tag is the whole distribution mechanism and the Release is human-facing
metadata:
  type: reference
---

Measured in `/opt/quarto/bin/quarto.js` against Quarto 1.10.18 (2026-08-29), `kGithubExtensionSource.urlProviders`:

```
| Command                          | Downloads                              |
| -------------------------------- | -------------------------------------- |
| quarto add owner/repo            | archive/refs/heads/main.tar.gz         |
| quarto add owner/repo@latest     | archive/refs/heads/main.tar.gz         |
| quarto add owner/repo@v1.4.0     | archive/refs/tags/v1.4.0.tar.gz        |
| quarto add owner/repo@<branch>   | archive/refs/heads/<branch>.tar.gz     |
```

`githubLatestUrlProvider` branches on `modifier === undefined || modifier === "latest"`, so the literal `latest` is the main branch, not the last published version.
There is no release-based provider: `getLatestRelease` (the `releases/latest` API call) exists in the bundle with TinyTeX as its only caller.

Consequences when maintaining an extension:

- An unpinned consumer tracks `main` and receives every push, tagged or not. Publishing is pushing.
- Only a tag makes an install reproducible, and GitHub serves the tag archive whether or not a Release exists. A failed `release.yml` does not break `@v1.4.0`.
- A GitHub Release is for readers and for extension listings, never for the installer.
- Bump and tag per coherent batch, not per feature: the numbering only reaches a consumer who pins. The real hazard is the opposite one, `main` drifting far ahead of the last tag while a pinned consumer sees none of it.

`quarto-hebstr-doc` documented the opposite ("resolves to the latest release if any tag exists") in `CONTRIBUTING.md` and its project `CLAUDE.md` until 2026-08-29; both are corrected.

Related: [[project_quarto_custom_crossref_float]], [[reference_quarto_extension_format_knitr]]
