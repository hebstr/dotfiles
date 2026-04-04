---
name: Verify R function exports before suggesting imports
description: Always confirm a function is exported before recommending @importFrom or namespace::fn — many functions exist in namespaces but are not public API
type: feedback
---

Never assume an R function is exported just because it appears in `ls(getNamespace('pkg'))`. Many functions are internal and not exported. Always verify with `pkg::fn_name` or check the package documentation before suggesting `@importFrom` directives or bare calls.

**Why:** Suggested `rlang::check_string()` as a fix in edstr, but this function is not exported in rlang 1.1.7. It exists in the namespace but is not part of the public API. The user caught the error before it shipped.

**How to apply:** Before recommending any package helper for an `@importFrom` directive, run `Rscript -e "pkg::fn_name"` to confirm it's exported. Fall back to manual validation with base R when no exported validator exists.
