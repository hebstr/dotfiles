# Installation globale des agent skills Streamlit

*2026-08-02T07:48:00Z by Showboat 0.6.1*
<!-- showboat-id: 6c86ff5d-4152-49b0-a80b-80bdb5842934 -->

Streamlit livre ses agent skills dans le paquet pip depuis la 1.57 ; le repo `streamlit/agent-skills` qui les hébergeait est archivé et `streamlit/streamlit` est la source canonique. Le mode global installe un méta-skill de quelques lignes dans le répertoire utilisateur, qui découvre à l'exécution le Streamlit du projet courant : une seule installation reste valable pour tous les projets, quelle que soit leur version de Streamlit. Le mode projet, lui, poserait des symlinks vers le venv, cassés à chaque rebuild.

Version installée dans le projet, et emplacement des skills empaquetés.

```sh
cd ~/Documents/des/eds/eds-prise
uv run python -c "import streamlit, pathlib; print(streamlit.__version__); print(pathlib.Path(streamlit.__file__).parent / \".agents\")"
```

```output
1.60.0
/home/julien/Documents/des/eds/eds-prise/.venv/lib/python3.13/site-packages/streamlit/.agents
```

Installation globale, non interactive.

```sh
cd ~/Documents/des/eds/eds-prise
uv run streamlit skills --global --yes
```

```output

✓ Installed:
  → ~/.agents/skills/developing-with-streamlit
  → ~/.claude/skills/developing-with-streamlit

✨ Successfully installed globally

Note: Global skills include a discover.py script that finds
      project-specific bundled skills at runtime.
```

Contrôle de ce qui a réellement été écrit : deux emplacements, `~/.agents/skills/` et `~/.claude/skills/`, chacun contenant le `SKILL.md` du méta-skill et son `discover.py`.

```sh
ls -l ~/.claude/skills/developing-with-streamlit
find ~/.agents/skills/developing-with-streamlit -type f | sort
head -4 ~/.agents/skills/developing-with-streamlit/SKILL.md
```

```output
total 8
drwxrwxr-x 2 julien julien 4096 Jul 25 23:43 scripts
-rw-rw-r-- 1 julien julien 1650 Jul 25 23:42 SKILL.md
/home/julien/.agents/skills/developing-with-streamlit/scripts/discover.py
/home/julien/.agents/skills/developing-with-streamlit/SKILL.md
---
name: developing-with-streamlit
description: "Use for ALL Streamlit tasks: creating, editing, debugging, beautifying, styling, theming, optimizing, or deploying Streamlit apps. Also custom components, st.components.v2, HTML/JS/CSS work. Discovers and loads version-matched reference docs from the user's installed Streamlit (>=1.57). Triggers: streamlit, st., dashboard, app.py, beautify, style, CSS, color, background, theme, button, widget styling, custom component, st.components, CCv2, session state, performance, cache, fragment, slow rerun, deploy."
allowed-tools: Bash(python ${CLAUDE_SKILL_DIR}/scripts/discover.py:*) Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/discover.py:*)
```

La promesse du mode global tient à `discover.py` : lancé depuis un projet, il doit résoudre le Streamlit de ce projet et pointer vers ses références empaquetées. Contrôle depuis `eds-prise` (venv uv, Streamlit 1.60).

```sh
cd ~/Documents/des/eds/eds-prise
python3 ~/.agents/skills/developing-with-streamlit/scripts/discover.py 2>&1 | head -30
```

```output
/home/julien/Documents/des/eds/eds-prise/.venv/lib/python3.13/site-packages/streamlit/.agents/skills/developing-with-streamlit/SKILL.md
```

Portée et réserve : le skill est un routeur, il ne charge qu'une ou deux références de `references/` selon la demande, le coût en contexte reste donc à la demande. Sa `description` est en revanche très large (elle liste `CSS`, `color`, `theme`, `button` parmi ses triggers) : elle se déclenchera aussi sur du CSS étranger à Streamlit, par exemple les thèmes Quarto. Ses conseils visent des dashboards génériques et restent une source, pas une autorité, face à du CSS écrit à la main.

Nature exacte des deux emplacements : ce sont deux copies indépendantes, pas un symlink vers l'autre, contrairement aux skills installés par plugin (`check`, `design`, `hunt`), où `~/.claude/skills/` pointe vers `~/.agents/skills/`. Conséquence : une mise à jour du méta-skill impose de relancer `streamlit skills --global`, qui réécrit les deux. Le contenu de référence, lui, n'est pas concerné, `discover.py` le résolvant à l'exécution dans le venv du projet.

```sh
ls -ld ~/.agents/skills/developing-with-streamlit ~/.claude/skills/developing-with-streamlit
stat -c "%i %n" ~/.agents/skills/developing-with-streamlit/SKILL.md ~/.claude/skills/developing-with-streamlit/SKILL.md
diff -q ~/.agents/skills/developing-with-streamlit/SKILL.md ~/.claude/skills/developing-with-streamlit/SKILL.md && echo "contenu identique"
```

```output
drwxrwxr-x 3 julien julien 4096 Jul 25 23:43 /home/julien/.agents/skills/developing-with-streamlit
drwxrwxr-x 3 julien julien 4096 Jul 25 23:43 /home/julien/.claude/skills/developing-with-streamlit
19281350 /home/julien/.agents/skills/developing-with-streamlit/SKILL.md
19940899 /home/julien/.claude/skills/developing-with-streamlit/SKILL.md
contenu identique
```
