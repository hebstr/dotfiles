# HANDOFF : migration opencode V1 -> V2

Ligne d'ouverture de la conversation cible : `/design migrer la config opencode et le plugin claude-hooks.ts à l'API V2`

## État actuel, avec l'évidence

- opencode 1.19.5 installé dans `~/.opencode/bin/opencode`, vérifié par `opencode --version`.
- Config stow : `~/dotfiles/opencode/.config/opencode/` (opencode.json, tui.json, plugins/claude-hooks.ts), symlinkée vers `~/.config/opencode/`.
- Diagnostic V2 fait le 2026-11-10 dans la conversation source, contre opencode.ai/docs (pages config, permissions, providers, skills, plugins, build/plugins/migrate-v1, cli/config). Il n'est écrit nulle part ailleurs.

## Ce que le diagnostic a établi

### Bloquant 1 : le plugin claude-hooks.ts est en API V1 et ne s'exécute pas sous V2

Trois hooks à porter, mappings donnés par /build/plugins/migrate-v1 :

- `experimental.chat.system.transform` -> `ctx.session.hook("context", ...)` sur `event.system`. Le strip du profil global Claude Code reconstruit aujourd'hui des blocs texte joints (`Instructions from: <file>\n<content>`), il faudra vérifier le format des blocs system en V2 (probablement `{type:"text", text}`) et adapter la reconstruction.
- `tool.execute.before` -> `ctx.tool.hook("execute.before", ...)`. La signature change : `(input, output)` séparés devient un seul `event` mutable (`event.tool`, `event.input`).
- `tool.execute.after` -> idem. **Décision à prendre** : la réécriture de l'output du tool (le rapport de format-on-edit.sh qui rejoint le modèle) n'est pas documentée dans le guide de migration. Si le mécanisme n'existe plus en V2, choisir entre un autre moyen de remonter le rapport ou l'abandonner. La note `~/dotfiles/.claude/DESIGN-OPENCODE-HARNESS.md`, section "The hooks plugin translates the payload and reports back to the model, 2026-09-21", dit que ce rapport est la raison d'être du hook PostToolUse.
- L'import change : `@opencode-ai/plugin` -> `@opencode/plugin`, l'export nommé devient un default export `Plugin.define({id, setup(ctx)})`.

### Bloquant 2 : le bloc `permission` devient `permissions` (tableau ordonné)

V2 = tableau de `{action, resource, effect}`, dernier match gagne (le fichier est déjà dans cet ordre, la conversion est mécanique). Mappings :

- `bash` -> `shell`. Les ressources sont produites par le scanner V2 qui extrait chaque sous-commande d'une commande composée et les teste séparément. L'allowlist de connecteurs (`;*`, `&&*`, `|*`, `2>&1*`) devient inutile. Le comportement sur les commandes composées change : le scanner peut refuser une syntaxe qu'il n'analyse pas (durcissement à vérifier en pratique).
- `external_directory` -> inchangé en nom, mais les ressources doivent finir par `/*`.
- `skill` -> inchangé.

### À convertir, non bloquant

- `skills` : objet `{paths: [...]}` -> tableau de chemins/URLs. Bonus : `~/.claude/skills` est détecté automatiquement en compat V2, on peut le retirer de la liste.
- `provider` (singulier) -> `providers`, et le schéma change : `"npm": "@ai-sdk/openai-compatible"` -> `"package": "@opencode/ai/providers/openai-compatible"`, `"options": {baseURL}` -> `"settings": {baseURL}`. Les deux providers llama.cpp (cpd, ju-tp2) passent tels quels sinon.
- `tui.json` -> `cli.json`, schéma `https://opencode.ai/v2/cli.json`. `theme: "system"` devient `{"theme": {"mode": "system"}}`, le bloc `attention` garde `notifications` et `sound` (le champ `enabled` n'existe plus).
- Installation V2 : `curl -fsSL https://opencode.ai/v2/install | bash`, à faire après la conversion de la config.

### Non impacté

AGENTS.md, watcher.ignore, model, `.opencode/bin/opencode-serve`.

## Ce que le lecteur ne doit pas faire

- Ne pas installer V2 avant d'avoir converti la config : V2 partirait sur une config illisible.
- Ne pas traiter le portage du plugin comme une traduction mécanique : les deux zones de décision ci-dessus (strip du system prompt, remontée du rapport format-on-edit.sh) méritent un choix explicite documenté dans la note.
- Ne pas réécrire l'allowlist bash sans revalider les résidus acceptés le 2026-11-05, documentés dans `DESIGN-OPENCODE-HARNESS.md` section "The read allowlist widened, 2026-11-05" : ils ont été mesurés contre le matching V1 (tree-sitter, texte source complet), et le scanner V2 change les règles.

## Ground truth de chaque étape

- État de la config : `cat ~/dotfiles/opencode/.config/opencode/opencode.json`
- Docs V2 : opencode.ai/docs/config, /permissions, /providers, /skills, /plugins, /build/plugins/migrate-v1, /cli/config
- Note de référence à lire en entier avant de proposer quoi que ce soit : `~/dotfiles/.claude/DESIGN-OPENCODE-HARNESS.md` (271 lignes, elle contient les décisions et mesures qui contraignent le portage)
- Test du plugin actuel : `_meta/tests/claude-hooks-plugin.bats` (il pilote le plugin via node contre des scripts stubs sous un HOME factice ; il faudra le porter avec le plugin)

## Bornes et pièges, datés

- 2026-11-08 : les deny git sont en forme substring (`git*push*`) parce que le scanner réécrit `cd X && git push` en `git -C X push`. En V2 le scanner est différent, la forme substring reste sûre mais il faut vérifier qu'elle ne sur-déclenche pas.
- 2026-11-08 : `skills.paths` pointe vers `~/.local/share/opencode/skills/{audit,workflow}` (clone hebstr/skills) et le farm est vide sur cpd. En V2 la compat `~/.claude/skills` est automatique, ce qui change l'ordre de priorité des sources : vérifier que les sept skills du clone ne sont pas masquées ou dupliquées.
- 2026-11-05 : le matching bash V1 teste chaque commande composée sur son texte source complet redirctions comprises ; c'est pour ça qu'il existe `"*>*": "ask"`. En V2 chaque sous-commande est extraite et testée séparément, la redirection n'est plus dans la ressource : les règles de take-back (`sort*-o*`, `tree*-o*`, `sed*-i*`) restent valables mais le rôle de `"*"` change.

## Ce qui est dû ailleurs et ne doit pas être plié ici

- La note `DESIGN-OPENCODE-HARNESS.md` porte les ouvertures "Next" (essai interactif, reviews adversariales) qui sont antérieures à cette migration et n'en font pas partie.
- Le portage du test `_meta/tests/claude-hooks-plugin.bats` suit le plugin, il ne s'invente pas séparément.

## Où va le compte rendu

La décision du design va dans `~/dotfiles/.claude/DESIGN-OPENCODE-HARNESS.md` (la note existe déjà et couvre le sujet), en anglais, avec la date absolue. L'implémentation suit dans la même conversation après approbation, puis commit selon la règle habituelle.
