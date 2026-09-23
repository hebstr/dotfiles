# Accès en lecture des agents Claude Code à la bibliothèque Zotero

Note de recherche issue de `/workflow:reco` (2026-09-23), dont la décision a été arrêtée par `/cadrer` le même jour.
L'API locale est activée par `user.js` depuis le 2026-09-23 ; aucun serveur MCP Zotero n'est installé.
Sources officielles lues dans le code de Zotero au tag `10.0.3` (via `gh api`) et sur les pages zotero.org, retorque.re et duckdb.org, vérifiées à cette date.

## Les agents passent par un skill et l'API locale, sans serveur MCP (décidé 2026-09-23)

Décision issue de `/cadrer` le 2026-09-23, qui renverse le choix provisoire de Zoteus pris le même jour par `/workflow:reco`.
Aucun serveur MCP Zotero.
Les agents interrogent l'API locale de Zotero (`localhost:23119/api/users/0/...`) en GET par `curl` et lisent le texte intégral dans `~/Zotero/storage/*/.zotero-ft-cache` par `rg`, selon les recettes d'un skill `zotero`.
Pas de pré-extraction ni d'index vectoriel pour l'instant.

### Trois usages délimitent le skill

- Retrouver une référence et sa clé Better BibTeX pour la citer dans un `.qmd` : recherche par auteur, titre, tag ou collection.
- Chercher dans le texte intégral (« quels articles parlent de X ») et citer un passage : `rg` sur les `.zotero-ft-cache` donne la clé de la pièce jointe, `parentItem` de l'API donne la notice.
- Obtenir le chemin d'un PDF pour une lecture approfondie selon `rules/pdf.md`.

Hors du périmètre : l'export d'une collection vers litrev (écarté par l'utilisateur le 2026-09-23, à rouvrir s'il revient), les annotations (0 dans la bibliothèque) et les notes (3), toute écriture.

### Le montage vit dans quatre fichiers versionnés (en place 2026-09-23)

- `zotero/.zotero/zotero/pucr7b5d.default/user.js` active l'API locale par `extensions.zotero.httpServer.localAPI.enabled` à `true` (nom et défaut `false` lus dans `defaults/preferences/zotero.js` au tag 10.0.3).
- `claude/.claude/skills/zotero/SKILL.md` porte les recettes des trois usages, chacune essayée sur la bibliothèque le 2026-09-23 avant d'y entrer. Le skill est invocable par le modèle et lié par `stow claude`, un lien par skill comme ses voisins. Un script dans `scripts/`, sur le modèle de `depouiller` et de son `scripts/squelette.py`, ne s'ajoute que si les agents composent mal leurs requêtes à l'usage.
- `claude/.claude/settings.json` porte `Bash(curl *better-bibtex/json-rpc*)` dans `permissions.deny`. Un appel `api.ready` au JSON-RPC a été refusé le 2026-09-23 sans invite.
- `opencode/.config/opencode/opencode.json` porte l'équivalent opencode, `"curl *better-bibtex/json-rpc*": "deny"` dans `permission.bash`, juste avant `"*>*": "ask"` (détail dans la section suivante).

Le skill sert aussi opencode, dont le harnais charge `~/.claude/skills`.

### Aucune règle `allow` pour les GET

Proposée puis retirée le 2026-09-23 avant écriture.
Selon la page « Configure permissions » de Claude Code, un `*` dans une règle Bash « matches any text, including spaces » : `Bash(curl -s http://localhost:23119/api/*)` approuverait donc aussi un `curl` qui ajoute une seconde URL et un fichier local à envoyer.
Le skill fait lire aux agents le texte intégral de documents tiers, donc un vecteur d'injection de consigne, et une telle règle transformerait une consigne injectée en envoi de fichier sans invite.
Chaque GET passe donc par l'invite, ou par le classifieur en mode auto.
Si les invites deviennent un frein, la voie est un script d'enveloppe qui ne prend qu'un chemin d'API et n'appelle que `localhost:23119`, autorisé par son nom.

### La lecture seule tient au seul verrou de Zotero

Un agent Claude Code dispose de Bash, donc de `curl` : il peut adresser une écriture à l'API locale ou au JSON-RPC de Better BibTeX quelle que soit la voie.
Le verrou réel est celui de Zotero, qui refuse toute écriture par l'API locale tant qu'aucune clé n'a été accordée dans sa boîte de dialogue : ne jamais cliquer « Allow ».
La règle `permissions.deny` sur le JSON-RPC est un garde-fou d'appoint, contournable par une commande reformulée.
`opencode.json` porte son équivalent depuis le 2026-09-23, `"curl *better-bibtex/json-rpc*": "deny"`, placé juste avant `"*>*": "ask"`, qui reste la dernière règle du bloc `bash` comme le décrivent `DESIGN-OPENCODE-HARNESS.md` et la trace `opencode-harness-setup.md`. Opencode retient la dernière règle qui correspond (page « Permissions » de opencode) : un appel au JSON-RPC portant une redirection demande donc confirmation au lieu d'être refusé. `opencode debug config` la restitue ; aucun refus n'a été observé en session opencode, faute de modèle servi pendant l'essai.

### Voies écartées

- **Zoteus en MCP, lecture seule** (le choix provisoire). `ZOTEUS_READ_ONLY=true` ne retire que des outils MCP et n'ajoute donc rien au verrou de Zotero. Le serveur est une dépendance tierce jeune (44 étoiles), dont le mode lecture seule n'est vérifié que pour `zotero_delete_items`. Sa déclaration vivrait dans `~/.claude.json`, qui n'est pas versionné. Et opencode ne le chargerait pas, `DESIGN-OPENCODE-HARNESS.md` gardant les serveurs MCP hors d'opencode depuis le 2026-09-21. Le repli par 54yyyu/zotero-mcp tombe pour les mêmes raisons.
- **Un serveur MCP maison dans un plugin**, sur le modèle de `litrev-mcp`. C'est la voie la plus coûteuse, un serveur à maintenir pour des lectures en GET, avec la même exclusion d'opencode, et aucun des trois usages ne demande d'outils typés.
- **Ne rien faire.** `rg` sur les `.zotero-ft-cache` fonctionne déjà, même Zotero ouvert, mais il ne renvoie que des clés de pièce jointe, sans notice ni clé de citation : il ne couvre que la moitié du deuxième usage.

### Les quatre GET répondent sans clé (mesuré 2026-09-23)

La décision tient tant que l'API locale répond sans clé aux GET dont les usages ont besoin.
Mesuré le 2026-09-23, Zotero 10.0.3 lancé avec la pref à `true`, sur la pièce jointe `8P9NJ7XL` et sa notice `Q5JEE39T` :

- `items?q=regression&format=json` renvoie les notices ; `Total-Results` porte le décompte (312 notices de premier niveau par `items/top`). Sur `q=bootstrap`, `qmode=titleCreatorYear` en trouve 3 et `qmode=everything` 33, contre 19 fichiers `.zotero-ft-cache` pour `rg -l -i -w` : l'API cherche donc aussi dans le texte intégral, sur un appariement plus large que le mot entier.
- `items/<pièce jointe>` donne `data.parentItem`, et `links.enclosure.href` le chemin `file://` du PDF dans `~/Zotero/storage/`, ce qui sert le troisième usage sans reconstruire le chemin.
- `items/<pièce jointe>/fulltext` renvoie `content` (40 999 caractères), `indexedPages` et `totalPages`.
- `data.citationKey` porte la clé Better BibTeX : sur `Q5JEE39T`, la valeur de l'API et celle de `item.citationkey` du JSON-RPC sont identiques (`newgardAdvancedStatisticsPropensity2004`), et les 100 premières notices de `items/top` ont toutes une clé. `format=bibtex` sort l'entrée sous cette même clé.
- Un `DELETE` sans clé reçoit `428`.

Les clés en place ne suivent pas la formule `auth.lower + year` de `citekeyFormat` : aucune des 100 notices lues n'a la forme courte, alors que `prefs.js` porte `autoPinMigrated`. Les clés semblent épinglées d'une formule antérieure, ce qui reste à confirmer. Le skill lit donc la clé dans `data.citationKey` et ne la recalcule jamais depuis la formule.
Résolu le même jour : l'utilisateur avait changé la formule à la main dans Zotero. Les 312 clés de `zotero.sqlite` (lu en `mode=ro`, Zotero fermé) suivent toutes la formule par défaut de Better BibTeX, `auth.lower + shorttitle(3,3) + year` (page « Citation keys » de Better BibTeX), et aucune n'a été créée sous `auth.lower + year`. À la demande de l'utilisateur, `user.js` rétablit cette formule par défaut dans `citekeyFormat` et y aligne `citekeyFormatEditing`, comme Better BibTeX le fait de lui-même quand ce champ est vide : le `prefs.js` de son `.xpi` livre `citekeyFormat` à `" auth.lower + shorttitle(3,3) + year"`, avec une espace initiale qu'il élague, et `citekeyFormatEditing` vide. Le skill continue de lire la clé plutôt que de la recalculer, puisqu'une clé peut être fixée à la main.

L'API exige que Zotero tourne : sans lui, seule la recherche `rg` fonctionne, et le skill demande alors de lancer Zotero.

### Ce qui reste valable de la recherche initiale

L'hypothèse de départ (DuckDB sur `zotero.sqlite` + pdf-inspector) est écartée pour les agents.
DuckDB reste valable pour des analyses par lot faites par l'utilisateur, Zotero fermé.
pdf-inspector reste l'outil de lecture approfondie d'un PDF précis, à la demande, selon `rules/pdf.md`.

## État local mesuré

Mesures du 2026-09-23, Zotero arrêté, bases ouvertes en `mode=ro&immutable=1`.

- Zotero 10.0.3, schéma userdata 129, répertoire `~/Zotero`.
- 295 PDF, 383 fichiers `.zotero-ft-cache` (PDF et instantanés HTML), 383 lignes dans `fulltextItems` dont 2 indexées partiellement (limite de 100 pages).
- 16 collections, 3 notes, 0 annotation dans `itemAnnotations`.
- `zotero.sqlite` est en WAL : octets 18-19 de l'en-tête à 2. `fulltext.sqlite` est en journal classique (octets à 1). Un `pragma journal_mode` sous `immutable=1` renvoie `delete` quel que soit le mode réel : lire l'en-tête.
- L'API locale est désactivée : aucune pref `httpServer.localAPI` dans `prefs.js`, donc la valeur par défaut `false`.
- Better BibTeX installé, clé de citation `auth.lower + year`.

## Ce que Zotero 10 a changé

Trois changements de la 10.0 invalident une partie de ce qui circule en ligne et dans les outils antérieurs.

- **WAL sous verrou exclusif.** `db.js` fixe `const DB_LOCK_EXCLUSIVE = true;` puis exécute `PRAGMA main.locking_mode=EXCLUSIVE` et `PRAGMA journal_mode=WAL`. Le WAL est absent en 9.0.6. Aucune pref `dbLockExclusive` n'existe en 7, 8, 9 ou 10.
- **Index plein texte déplacé.** `fulltextWords` et `fulltextItemWords` ont disparu de `zotero.sqlite`. L'index vit dans `fulltext.sqlite`, en tables FTS5 `content=''` (contentless). Il indique quels items contiennent un terme mais ne restitue aucun texte. Selon `fulltext.js` : « The original extracted text still lives in the .zotero-ft-cache files ».
- **API locale en écriture.** Les requêtes GET restent sans authentification ; les écritures exigent une clé accordée par l'utilisateur et un en-tête `Zotero-Server-ID`.

## Voies d'accès comparées

- **SQLite direct (DuckDB ou autre).**
  - Zotero ouvert : la base est verrouillée.
  - `immutable=1` contourne le verrou mais ignore le WAL, donc les items récents manquent (ticket 54yyyu #536).
  - Une copie `.sqlite` + `-wal` n'est cohérente que si aucun point de contrôle ne tombe pendant la copie.
  - Le schéma n'est pas un contrat : la page officielle le dit, et ZotPilot interroge encore `fulltextWords`.
  - Zotero fermé, la lecture est sûre : le WAL est tronqué à l'arrêt.
- **API locale.**
  - Données en direct, sans limite de débit, format de l'API web v3. Zotero doit tourner.
  - `GET /api/users/0/items/<key>/fulltext` lit le `.zotero-ft-cache` (`getItemCacheFile` dans `server_localAPI.js`).
  - Les annotations sont des items enfants de type `annotation`.
- **API web.** Passe par la synchronisation, donc par un compte et une clé. Limite de 100 résultats par requête, ralentissement par `Backoff` et `429`. Sans intérêt pour une bibliothèque locale.
- **Better BibTeX JSON-RPC** (`/better-bibtex/json-rpc`).
  - Utile pour les clés de citation, les notes et les collections par clé.
  - Ne renvoie aucun texte intégral. Pour les annotations, la page de doc n'en mentionne pas, alors que le source de `item.attachments` les renvoie (lu par un sous-agent, non revérifié).
  - Pas d'authentification, et des méthodes à effet de bord (`autoexport.add`, `item.regenerate_key`, `collection.scanAUX`). Ne pas l'exposer brut aux agents.
- **litrev.** `import_corpus` lit du BibTeX ou du RIS et ignore collections, notes, annotations et PDF locaux. `fetch_fulltext` récupère le texte en ligne par DOI. C'est l'outil des revues, pas celui de l'accès à la bibliothèque.

## Serveurs publiés

Étoiles et date du dernier push relevées par `gh api` le 2026-09-23.

| Dépôt | Étoiles | Dernier push | Voie | Lecture seule |
|---|---|---|---|---|
| 54yyyu/zotero-mcp | 5123 | 2026-09-21 | Instantané SQLite (copie `.sqlite` + `-wal` depuis 0.12.0) ou API web | Aucun interrupteur ; écritures bloquées tant qu'aucune clé n'est accordée |
| oscardvs/zoteus | 44 | 2026-09-23 | API locale d'abord, API web en repli | `ZOTEUS_READ_ONLY=true` |
| kujenga/zotero-mcp | 162 | 2026-08-07 | API locale ou web (pyzotero) | Par construction, mais 3 outils sans collections, tags, notes ni annotations |
| introfini/ZotSeek | 212 | 2026-09-22 | Extension Zotero, MCP sur `/zotseek/mcp` | Oui, mais recherche seule, aucun texte renvoyé |
| docsagent/docsagent | 616 | 2026-09-21 | SQLite et `storage/` en direct | `enableWrites=false` par défaut |
| cookjohn/zotero-mcp | 1175 | 2026-09-09 | Extension Zotero, serveur sur le port 23120 | Écritures désactivables dans les préférences |
| xunhe730/ZotPilot | 73 | 2026-06-28 | SQLite `immutable=1` + ChromaDB | Non ; recherche plein texte cassée par Zotero 10 (déduit du code) |

## Texte intégral

`.zotero-ft-cache` suffit pour la recherche par mots-clés et pour citer un passage : fichiers texte ordinaires, lisibles par `rg` même quand Zotero tourne.
Deux limites connues : l'extraction de Zotero (PDF worker, sans OCR) plafonne à 100 pages et 500 000 caractères par défaut (`fulltext.pdfMaxPages`, `fulltext.textMaxLength`), et elle ne rétablit pas l'ordre de lecture des mises en page à colonnes.
`pdf2md` corrige l'ordre de lecture mais garde les défauts mesurés dans `pdf-inspector-reco.md` ; il sert à la lecture approfondie d'un article, pas à une pré-extraction de la bibliothèque.
Index vectoriel : les outils mûrs le rendent optionnel et livrent BM25 ou mots-clés par défaut, et personne ne publie de seuil de taille. Il ne se justifie ici que si les requêtes floues (« les papiers sur X ») s'avèrent un besoin réel.

## Bonnes pratiques retenues

- Ne jamais écrire dans `zotero.sqlite` ni dans `fulltext.sqlite`.
- Pour une lecture SQLite, Zotero fermé, ouvrir en `mode=ro` sans `immutable`, pour échouer bruyamment si Zotero tourne au lieu de lire des données périmées.
- Ne jamais copier `zotero.sqlite` sans son `-wal` pendant que Zotero tourne.
- Ne jamais accorder de clé d'écriture de l'API locale à un agent.
- Ne pas exposer le JSON-RPC de Better BibTeX brut aux agents.

## Non vérifié

- Le comportement de `ZOTEUS_READ_ONLY=true` sur les outils autres que `zotero_delete_items`.
- Si le verrou exclusif de Zotero s'étend à `fulltext.sqlite` attaché : `main.locking_mode` ne vise que la base principale.
- Le comportement d'un `ATTACH ... (TYPE sqlite, READ_ONLY)` DuckDB sur la base vivante, déduit de la doc DuckDB et non testé.

## Sources

- Code de Zotero au tag 10.0.3 : `chrome/content/zotero/xpcom/db.js`, `chrome/content/zotero/xpcom/fulltext.js`, `chrome/content/zotero/xpcom/server/server_localAPI.js`, `defaults/preferences/zotero.js`, dans <https://github.com/zotero/zotero>.
- <https://www.zotero.org/support/dev/web_api/v3/local_api>
- <https://www.zotero.org/support/dev/client_coding/direct_sqlite_database_access>
- <https://retorque.re/zotero-better-bibtex/exporting/json-rpc/>
- <https://duckdb.org/docs/current/core_extensions/sqlite.html>
- <https://github.com/54yyyu/zotero-mcp/issues/536>
- <https://github.com/oscardvs/zoteus>
- <https://github.com/54yyyu/zotero-mcp>
- <https://github.com/kujenga/zotero-mcp>
