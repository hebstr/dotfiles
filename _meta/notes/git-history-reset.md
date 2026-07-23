# Reset repo history to a single v0.1.0 commit

Procedure to squash all history of a solo repo into one root commit tagged `v0.1.0`, overwriting prior tags and remote history.
Destructive; assumes no third-party users.

## Prerequisites

- Solo repo, force-push acceptable
- Clean working tree except for files intentionally modified for the reset
- `gh` CLI authenticated
- A backup ref is created at step 2 as a safety net

## Step 1: rewrite CHANGELOG

The release workflow (see § Reference) extracts the section header via `awk "/^## \[$VERSION\]/"` with `VERSION=${GITHUB_REF_NAME#v}`.
The header must match exactly.
Target structure:

```markdown
# Changelog

...

## [Unreleased]

## [0.1.0] - YYYY-MM-DD

Initial release.

### `<feature-a>`
- ...

### `<feature-b>`
- ...

[Unreleased]: https://github.com/<owner>/<repo>/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/<owner>/<repo>/releases/tag/v0.1.0
```

No `v` prefix, no `<feature>-` prefix in the version header.

## Step 2: sanity check and safety net

```bash
git status              # only intentional files in modified
git diff CHANGELOG.md   # final content review
git branch backup-old-main main
```

The backup branch can be deleted after full validation or kept locally indefinitely.

## Step 3: squash into orphan commit

```bash
git checkout --orphan fresh    # new branch with no parent, working tree preserved
git add -A                     # gitignore still applies
git commit -m "initial release"
git branch -D main
git branch -m main             # rename fresh to main
```

## Step 4: local tags

```bash
git tag -d v0.1.0 v0.2.0 v0.3.0        # adapt to actual list
git tag -a v0.1.0 -m "Initial release" # annotated tag
```

## Step 5: force-push

```bash
git push --force-with-lease origin main
git push origin --delete v0.2.0 v0.3.0   # adapt to actual list
git push origin v0.1.0 --force            # overwrite existing remote tag
```

`--force-with-lease` refuses if the remote moved since last fetch.

## Step 6: trigger or create the GitHub release

A `git push --force` on an existing tag does not always re-trigger the `release.yml` workflow (GitHub may deduplicate the event).
Check first:

```bash
gh run list -R <owner>/<repo> --workflow=release.yml --limit 3
```

If the workflow did not fire, use Option A (manual, reproduces the workflow extraction):

```bash
BODY=$(awk '/^## \[0.1.0\]/{found=1; next} /^## \[/{if(found) exit} found' CHANGELOG.md)
gh release create v0.1.0 --title "v0.1.0" --notes "$BODY"
```

Or Option B (delete and repush, the create event is new):

```bash
git push origin --delete v0.1.0
git push origin v0.1.0
gh run watch
```

## Step 7: clean up orphan releases

Deleting a tag does not delete its associated GitHub Release.
Orphan releases appear as `Draft` in `gh release list`.

```bash
gh release list -R <owner>/<repo>
gh release delete v0.2.0 -R <owner>/<repo> --yes
gh release delete v0.3.0 -R <owner>/<repo> --yes
```

## Step 8: final verification

```bash
gh api repos/<owner>/<repo>/commits/main --jq '{sha:.sha[0:7], parents:[.parents[].sha[0:7]]}'
# expect: parents == []
gh api repos/<owner>/<repo>/tags --jq '.[].name'
# expect: only the new tag
gh release list -R <owner>/<repo>
# expect: only v0.1.0 marked Latest
```

## Reversibility

  | Step             | Recoverable?   | How                                                                           |
  | ---------------- | -------------- | ----------------------------------------------------------------------------- |
  | 3 (delete main)  | Yes via reflog | `git branch main <old-sha>` (~30 days before GC)                              |
  | 4 (local tags)   | Yes via reflog | Tagged commits aren't immediately destroyed                                   |
  | 5 (push --force) | Difficult      | Without a local backup, remote history is lost. Practical point of no return. |
  | 6-7              | Trivial        | Re-tag and re-push from local                                                 |

The `backup-old-main` from step 2 is the safety net until step 8 succeeds.

## Reference: `release.yml`

```yaml
name: Release
on:
  push:
    tags: ["v*.*.*"]
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - id: changelog
        run: |
          VERSION=${GITHUB_REF_NAME#v}
          BODY=$(awk "/^## \[$VERSION\]/{found=1; next} /^## \[/{if(found) exit} found{print}" CHANGELOG.md)
          echo "body<<EOF" >> "$GITHUB_OUTPUT"
          echo "$BODY" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"
      - uses: softprops/action-gh-release@v2
        with:
          body: ${{ steps.changelog.outputs.body }}
```

If the versioning scheme changes, three things must stay aligned: the `on.push.tags` filter, the awk regex `/^## \[$VERSION\]/`, and the CHANGELOG header format.
