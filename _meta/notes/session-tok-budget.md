# Budget de tokens injecté en début de session Claude Code

Analyse de la config `~/.claude/` et coût en tokens du contexte injecté à chaque session.

Date : 2026-07-07.
Machine : dotfiles `hebstr`.
**Chiffres corrigés contre la vérité terrain `/context`** (les estimations hors-ligne initiales étaient fausses sur la composition ; détail en fin de doc).

## TL;DR

Empreinte de démarrage stable (avant tout travail) : **\~37k tokens**, ventilés par `/context` en :
System prompt 2,7k + outils actifs 8,2k + fichiers mémoire 16,1k + skills 10k.

- **CLAUDE.md = 12,8k tokens à lui seul**, soit \~34 % de l'empreinte stable et de loin ton plus gros levier direct.
- En plus, **\~30,6k tokens de schémas d'outils différés** (MCP ouroboros 14,3k + outils système différés 16,3k) sont **latents à coût 0** : chargés uniquement quand tu les invoques via ToolSearch, pas au démarrage.
- Mesure prise avec \~38k tokens de « Messages » (cette conversation + sorties de hook), total contexte 74,7k / 1M (7 %).

## Vérité terrain `/context` (2026-07-07)

  | Catégorie                             | Tokens    | % du 1M | Dans le contexte au démarrage ?      |
  | ------------------------------------- | --------: | ------: | ------------------------------------ |
  | System prompt                         |      2,7k |   0,3 % | oui                                  |
  | System tools (actifs, 12 outils)      |      8,2k |   0,8 % | oui                                  |
  | **Memory files**                      | **16,1k** |   1,6 % | oui                                  |
  | Skills (101 skills)                   |       10k |   1,0 % | oui (métadonnées)                    |
  | Messages (conversation + hooks)       |     38,1k |   3,8 % | variable                             |
  | MCP tools **différés** (29 ouroboros) |     14,3k |   1,4 % | **non, 0 tok tant que non invoqués** |
  | System tools **différés**             |     16,3k |   1,6 % | **non, 0 tok tant que non invoqués** |
  | Free space                            |      925k |  92,5 % |                                      |

Empreinte stable catégorisée = System prompt + outils actifs + memory + skills = **\~37k tokens**.

## Détail « Memory files » (16,1k)

  | Fichier                             | Tokens | car./token effectif |
  | ----------------------------------- | -----: | ------------------: |
  | `~/.claude/CLAUDE.md` (37 303 car.) |  12,8k |                 2,9 |
  | `rules/environment.md` (3 936 car.) |   1,7k |                 2,3 |
  | `rules/secrets.md` (2 572 car.)     |    987 |                 2,6 |
  | `rules/showboat.md` (1 344 car.)    |    493 |                 2,7 |
  | Stub AutoMem `MEMORY.md` (407 car.) |    149 |                 2,7 |

Point non intuitif : **l'index mémoire canonique** (`~/.claude/memory/MEMORY.md`, 45 entrées, 9,7 kc) **n'est PAS dans cette catégorie.** Il est injecté par le hook SessionStart et compte donc dans **Messages**, pas dans Memory files.
À \~2,7 car./token il pèse \~3,6k tokens, présents à chaque session malgré son classement en « Messages ».

Les 6 rules langage (`python`/`r`/`shell`/`rust`/`quarto`/`typst`, 26,8 kc) et les 44 corps de fichiers mémoire (132 kc) restent chargés à la demande : 0 token au démarrage.

## Ce qui est réellement sous ton contrôle (par tokens réels)

1. **CLAUDE.md : 12,8k tokens.** Levier n°1, incompressible autrement qu'en déplaçant du contenu vers des `rules/*.md` on-demand.
   Déplacer les sections opérationnelles longues (greps post-changement, séquences de gate, « Build discipline ») vers des rules chargées à l'édition économiserait plusieurs milliers de tokens à chaque session où aucun code n'est touché.
2. **Skills : 10k tokens pour 101 skills.** Piloté par les plugins.
   Les gros contributeurs : `audit:walkthrough` (\~520), `bookmarks-manager` (\~520), `dataviz` (\~380), `claude-api` (\~360), `ref` (\~260), `workflow:reco` (\~240).
   Les \~35 entrées ouroboros pèsent < 20 à \~70 chacune mais s'additionnent.
   Désinstaller un marketplace non utilisé (`mcp-server-dev`, `frontend-design`, `ggsql`) récupère quelques centaines de tokens.
3. **Index mémoire (\~3,6k, via hook, classé Messages) + 3 rules always-on (3,2k).** L'index croît d'\~1 ligne par nouveau fichier `feedback_*`.
   Consolider les 15+ `feedback_review_severity_*` réduirait les lignes injectées.
4. **Ne touche pas** : System prompt et outils actifs (harness), outils différés (déjà à 0), rules on-demand et corps mémoire (déjà à 0 au démarrage).

## Le levier caché : les outils différés

30,6k tokens de schémas (MCP ouroboros 14,3k + built-ins différés type `WebFetch`, `WebSearch`, `Cron*`, `Task*`, `Monitor`, `NotebookEdit`, `LSP`, 16,3k) sont **hors contexte par défaut** et ne se matérialisent qu'à l'appel via ToolSearch.
C'est le mécanisme qui garde l'empreinte de démarrage à \~37k plutôt que \~68k.
Corollaire pratique : invoquer un outil ouroboros ou `WebFetch` dans une session « coûte » son schéma une fois chargé ; sur une session qui n'en a pas besoin, c'est gratuit.

## Réconciliation avec l'estimation hors-ligne initiale

Le total estimé (\~40k) tombait proche du réel (\~37k stable) mais par compensation d'erreurs :

  | Poste                   | Estimé | Réel                        | Erreur                                                                             |
  | ----------------------- | -----: | --------------------------: | ---------------------------------------------------------------------------------- |
  | CLAUDE.md               |   9,6k |                       12,8k | ratio car./token trop haut (3,9 au lieu de 2,9 : config dense en ponctuation/refs) |
  | Outils actifs           |   ~14k |                        8,2k | surestimé                                                                          |
  | Skills                  |   8,2k |                         10k | légèrement sous-estimé                                                             |
  | Instructions MCP        |  ~0,6k | 14,3k **différé (0 actif)** | catégorie « différé » ignorée                                                      |
  | Outils différés système |  ~0,8k | 16,3k **différé (0 actif)** | catégorie « différé » ignorée                                                      |
  | Index mémoire           |   2,5k |                       ~3,6k | ratio trop haut ; et classé Messages, pas Memory                                   |

Leçon de calibration : la prose technique dense de cette config tokenise à **\~2,6--2,9 car./token**, pas 3,7--3,9.
Toute future estimation hors-ligne sur ces fichiers doit utiliser \~2,8 car./token.
