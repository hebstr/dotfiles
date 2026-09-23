# Accès en lecture des agents Claude Code à la bibliothèque Zotero

Note de recherche issue de `/workflow:reco` (2026-09-23).
Aucune action engagée : l'API locale reste désactivée et aucun serveur MCP Zotero n'est installé.
Sources officielles lues dans le code de Zotero au tag `10.0.3` (via `gh api`) et sur les pages zotero.org, retorque.re et duckdb.org, vérifiées à cette date.

## Décision

Passer les agents par l'API locale de Zotero (`localhost:23119/api/`), servie par Zoteus avec `ZOTEUS_READ_ONLY=true` et sans clé cloud.
Texte intégral lu dans les `.zotero-ft-cache`, sans pré-extraction ni index vectoriel pour l'instant.
Confiance moyenne : Zoteus est jeune (44 étoiles) et son mode lecture seule n'a pas été testé sur cette installation.
Repli si l'essai déçoit : 54yyyu/zotero-mcp, avec ses outils d'écriture bloqués par `permissions.deny` dans Claude Code.

La lecture seule repose sur deux verrous indépendants.
`ZOTEUS_READ_ONLY=true` retire les outils d'écriture de la liste (vérifié dans le README pour `zotero_delete_items` seulement).
Zotero refuse toute écriture par l'API locale tant qu'aucune clé n'a été accordée dans sa boîte de dialogue : ne jamais cliquer « Allow ».

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
- `GET /fulltext` sur l'API locale en conditions réelles : Zotero était fermé et l'API locale désactivée pendant la recherche. Le code du tag 10.0.3 le sert.
- Si le verrou exclusif de Zotero s'étend à `fulltext.sqlite` attaché : `main.locking_mode` ne vise que la base principale.
- Le comportement d'un `ATTACH ... (TYPE sqlite, READ_ONLY)` DuckDB sur la base vivante, déduit de la doc DuckDB et non testé.

## Sources

- Code de Zotero au tag 10.0.3 : `chrome/content/zotero/xpcom/db.js`, `chrome/content/zotero/xpcom/fulltext.js`, `chrome/content/zotero/xpcom/server/server_localAPI.js`, dans <https://github.com/zotero/zotero>.
- <https://www.zotero.org/support/dev/web_api/v3/local_api>
- <https://www.zotero.org/support/dev/client_coding/direct_sqlite_database_access>
- <https://retorque.re/zotero-better-bibtex/exporting/json-rpc/>
- <https://duckdb.org/docs/current/core_extensions/sqlite.html>
- <https://github.com/54yyyu/zotero-mcp/issues/536>
- <https://github.com/oscardvs/zoteus>
- <https://github.com/54yyyu/zotero-mcp>
- <https://github.com/kujenga/zotero-mcp>
