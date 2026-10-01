# Shaping cake sur le tunnel WARP

*2026-10-01T14:28:36Z by Showboat 0.6.1*
<!-- showboat-id: 5638ae9d-aa80-4a5a-8f50-80f4b5a2b6f5 -->

## Contexte

Coupures intempestives de Claude Code (« waiting for API ») le 2026-10-01, sur un réseau qui paraît sain.

Chaîne réseau : ju-TP → partage de connexion wifi `ju-DG` (172.30.227.0/24) → Cloudflare WARP always-on (tun `CloudflareWARP`, MTU 1280, tout le v4 et le v6 routé dedans, table 65743) → Anthropic.
`api.anthropic.com` résout en `2607:6bc0::10`, joignable en IPv6 uniquement à travers WARP, le lien wifi ne portant aucune adresse v6 globale.

## Écarté par la mesure

Wifi : signal 94 %, -52 dBm, 0 erreur, 0 paquet dropé, aucune déconnexion ni réassociation dans le journal sur 3 h 30.
Tunnel : 108 échantillons `warp-stats`, perte 0,0 % partout, latence p50 48 ms, p90 68 ms, max 233 ms.
DNS : 1 ms en cache, résolution correcte en v4 et v6.
API : TTFB 150–190 ms, identique en IPv4 et IPv6, TLS ~85 ms.
Aucune entrée d'erreur API ou réseau dans les transcripts du jour.
Un grep naïf en remonte deux sortes, toutes deux fausses : la commande d'investigation d'une session eds-prise antérieure, qui porte `overloaded_error` comme motif de recherche, et la sous-chaîne `stream error` à l'intérieur de « downstream errors » dans le contenu d'un fichier de mémoire.

## Diagnostic

Bufferbloat du lien montant, pas une rupture de lien.
Débit montant réel 775 ko/s (6,2 Mbit/s).
`fq_codel` sur le tunnel affiche 0 drop et un backlog vide : la file saturée est en aval, dans le partage de connexion ou chez l'opérateur, pas sur la machine.

Le déclencheur est la forme du trafic de Claude Code : l'API Messages est sans état, donc chaque requête réuploade toute la conversation et toutes les définitions d'outils, les deux serveurs MCP toujours chargés (ouroboros, litrev) compris.
Le tunnel a envoyé 185 MiB contre 52 MiB reçus en 3 h 34.
WARP agrège tout dans un seul flux UDP, donc le blocage devient global au lieu de rester sur l'upload : les deux `HANDSHAKE(KEEPALIVE + REKEY_TIMEOUT)` du journal sont le rekey du tunnel lui-même coincé derrière la file pleine.

## Mesure de référence, avant shaping

Non rejouable automatiquement : le test consomme 12 Mo de données mobiles.

~~~text
$ ping -n -c 10 -i 1 -W 3 1.1.1.1
rtt min/avg/max/mdev = 30.611/43.882/53.255/6.170 ms

$ curl -X POST --data-binary @blob12M https://speed.cloudflare.com/__up
upload: 12000000 octets en 15.471561s => 775616 o/s

$ ping -n -c 25 -i 0.5 -W 5 1.1.1.1   # pendant l'upload
25 packets transmitted, 25 received, 0% packet loss
rtt min/avg/max/mdev = 45.286/369.189/877.421/236.838 ms
~~~

## Application du shaping

Étape `sudo`, non rejouable.

~~~text
$ sudo tc qdisc replace dev CloudflareWARP root cake bandwidth 5Mbit
$ tc -s qdisc show dev CloudflareWARP
qdisc cake 8001: root refcnt 257 bandwidth 5Mbit diffserv3 triple-isolate nonat nowash no-ack-filter split-gso rtt 100ms raw overhead 0
 capacity estimate: 5Mbit
~~~

5 Mbit sur l'interface interne laisse environ 20 % de marge sous le pic mesuré.
Cette marge absorbe l'encapsulation WireGuard et la variation du débit de la cellule : un shaper réglé au-dessus du goulot réel rend la file à l'opérateur et annule le bénéfice.

## Mesure après shaping, mêmes paramètres

~~~text
$ ping -n -c 10 -i 1 -W 3 1.1.1.1
rtt min/avg/max/mdev = 27.546/36.456/52.849/7.333 ms

$ curl -X POST --data-binary @blob12M https://speed.cloudflare.com/__up
upload: 12000000 octets en 21.074969s => 569395 o/s

$ ping -n -c 25 -i 0.5 -W 5 1.1.1.1   # pendant l'upload
25 packets transmitted, 25 received, 0% packet loss
rtt min/avg/max/mdev = 27.387/35.509/50.898/5.290 ms
p50 33.5 ms, p90 40.1 ms
~~~

La latence sous charge rejoint la latence au repos : 35,5 ms de moyenne contre 369 ms avant, 50,9 ms de pointe contre 877 ms.
Coût : 27 % du débit montant de pointe, soit 6,2 Mbit/s ramenés à 4,6 Mbit/s effectifs.

```bash
tc -s qdisc show dev CloudflareWARP | rg -N "qdisc cake|capacity estimate|overlimits|av_delay|pk_delay"
```

```output
qdisc cake 8001: root refcnt 257 bandwidth 5Mbit diffserv3 triple-isolate nonat nowash no-ack-filter split-gso rtt 100ms raw overhead 0 
 Sent 16106913 bytes 15172 pkt (dropped 6, overlimits 31104 requeues 0) 
 capacity estimate: 5Mbit
  pk_delay          0us       8.24ms          0us
  av_delay          0us        3.5ms          0us
```

## Persistance

Le qdisc disparaît dès que WARP recrée son interface, c'est-à-dire à chaque `warp-cli disconnect` puis `connect` et à chaque démarrage.
Le root qdisc redevient alors `mq` + `fq_codel` sans shaping, et le symptôme revient sans que rien le signale.

NetworkManager voit l'interface comme « connecté (en externe) », ce qui rend un dispatcher NM peu fiable ici.
Le déclencheur retenu est l'unité device systemd `sys-subsystem-net-devices-CloudflareWARP.device`, présente et active sur la machine, qui démarre le service à chaque apparition de l'interface et l'arrête à sa disparition via `BindsTo`.

La source de l'unité est versionnée dans `_meta/warp-cake/etc/systemd/system/warp-cake.service`, sur le modèle de `_meta/backup/.config/systemd/user/`.

Installation, étape `sudo`, non rejouable.

~~~text
$ sudo install -m 644 ~/dotfiles/_meta/warp-cake/etc/systemd/system/warp-cake.service /etc/systemd/system/warp-cake.service
$ sudo systemctl daemon-reload
$ sudo systemctl enable --now warp-cake.service
~~~

## Vérification de la persistance

`systemctl enable` avertit que l'unité device est inexistante.
L'avertissement ne concerne que la vue hors ligne, où une unité device n'est pas un fichier : au runtime l'unité existe, l'interface porte le tag udev `systemd`, et le lien est établi dans les deux sens, `Wants=warp-cake.service` sur le device et `BoundBy=warp-cake.service` en retour.

Cycle complet de l'interface, étape perturbante non rejouable puisqu'elle coupe le tunnel une dizaine de secondes.

~~~text
$ tc qdisc show dev CloudflareWARP        # avant
qdisc cake 8001: root bandwidth 5Mbit ...

$ warp-cli disconnect
Success
# interface détruite

$ warp-cli connect
Success

$ tc -s qdisc show dev CloudflareWARP     # après
qdisc cake 8002: root bandwidth 5Mbit ...
 Sent 20489 bytes 42 pkt (dropped 1, overlimits 32 requeues 0)
 capacity estimate: 5Mbit
~~~

Le `handle` passe de 8001 à 8002 : le qdisc est bien neuf, reposé par l'unité, et il shape déjà (32 `overlimits`).
Le journal confirme les deux transitions, `BindsTo` arrêtant le service à la destruction de l'interface et le device le redémarrant à sa réapparition.

~~~text
16:36:26 warp-cake.service: Deactivated successfully.
16:36:26 Stopped warp-cake.service - CAKE shaper on the Cloudflare WARP tunnel.
16:36:32 Starting warp-cake.service - CAKE shaper on the Cloudflare WARP tunnel...
16:36:32 Finished warp-cake.service - CAKE shaper on the Cloudflare WARP tunnel.
~~~

État permanent, rejouable :

```bash
tc qdisc show dev CloudflareWARP | head -1; systemctl is-active warp-cake.service; systemctl is-enabled warp-cake.service
```

```output
qdisc cake 8002: root refcnt 257 bandwidth 5Mbit diffserv3 triple-isolate nonat nowash no-ack-filter split-gso rtt 100ms raw overhead 0 
active
enabled
```

## Point ouvert

L'unité pose 5 Mbit sans condition, à chaque apparition de l'interface et donc sur tous les réseaux.
La valeur est calibrée sur le partage de connexion `ju-DG` : sur un lien plus rapide, une box par exemple, elle plafonnerait le tunnel bien en dessous de ce que le lien offre, transformant le correctif en goulot.

Deux issues, à trancher quand la question se posera sur un autre réseau :

- arrêter le service à la main sur un lien rapide (`sudo systemctl stop warp-cake.service`), le shaping revenant au cycle suivant de l'interface ;
- conditionner le `ExecStart` au SSID actif, mécaniquement décidable avec `nmcli -t -f ACTIVE,SSID dev wifi`, ce qui demande un script au lieu de la commande unique de l'unité.

Rien n'est décidé ici : la mesure qui justifierait le seuil d'un autre réseau n'a pas été faite.

