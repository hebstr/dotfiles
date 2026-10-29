---
name: Positron's GIT_ASKPASS turns a missing credential into "Access denied"
description: In a Positron integrated terminal GIT_ASKPASS makes git send an empty Basic auth, so a private HTTPS clone fails on the host's "Access denied" instead of prompting; how to get the real error, and why a GitLab 404 settles nothing
metadata:
  type: reference
---

Positron's git extension injects `GIT_ASKPASS=/usr/share/positron/resources/app/extensions/git/dist/askpass.sh` into every integrated terminal (with `VSCODE_GIT_ASKPASS_NODE` and `VSCODE_GIT_ASKPASS_MAIN` beside it). Called outside the GUI it answers git with nothing usable, git sends an empty Basic auth, and the host rejects a failed authentication rather than asking for one. On gitlab.com that reads:

```
remote: HTTP Basic: Access denied. If a password was provided for Git authentication, the password was incorrect...
```

which sends you hunting for a wrong stored token when none is stored at all. The real error comes out once the variable is gone:

```bash
env -u GIT_ASKPASS -u VSCODE_GIT_ASKPASS_NODE -u VSCODE_GIT_ASKPASS_MAIN \
  GIT_TERMINAL_PROMPT=0 git ls-remote <url>
# fatal: could not read Username for 'https://gitlab.com': terminal prompts disabled
```

`git ls-remote` over `git clone` for the whole diagnostic phase: same authentication exchange, no directory created on failure. The same `env -u` with `GIT_TERMINAL_PROMPT=1` is what restores an interactive prompt for a PAT (typed at the prompt, never as an argument).

Measured 2026-10-29 cloning `gitlab.com/include-project/doc_eds`, with `credential.helper=cache` empty, no `.netrc` and no `~/.git-credentials`: nothing but the askpass was in play.

Two things that mislead in the same diagnostic:

- **GitLab answers 404 for a private project**, not 403, so `curl -o /dev/null -w '%{http_code}' https://gitlab.com/api/v4/projects/<group>%2F<project>` cannot tell a private repository from a wrong path. The `%2F` encoding of the path is required.
- **`ssh -T git@host` never says which key was refused**, nor whether one was offered: keys with non-default names are only proposed through a `~/.ssh/config` entry. Test them one by one with `-i ~/.ssh/<key> -o IdentitiesOnly=yes -o BatchMode=yes`, without which every test measures the agent's whole keyring and a passphrase prompt stalls the loop.

The per-host alias in `ssh/.ssh/config` (sha `fd0b7cd` added `gitlab-include`) carries `IdentitiesOnly yes` for the same reason: without it ssh offers the agent's keys first and the host may accept one tied to another account, succeeding under the wrong identity.

Related: [[reference_quarto_r_env_var]] (the same extension injecting `QUARTO_R` and `QUARTO_PYTHON`, stale at terminal creation), [[reference_bash_tool_pitfalls]]
