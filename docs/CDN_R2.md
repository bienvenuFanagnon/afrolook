# CDN des médias : Cloudflare R2 devant Firebase Storage (17 octobre 2026)

## Pourquoi
Le trafic sortant de Cloud Storage est passé de 2,5 Go/jour (9 oct.) à 33 Go/jour (16 oct.), soit environ 4 $/jour (0,12 $/Go) : c'était
la cause de l'alerte à 10 $. Le Worker du CDN relayait chaque lecture vers Google sans rien mettre en cache (`cf-cache-status: BYPASS`).
R2 n'a pas de frais de sortie : les lectures y sont gratuites (10 millions de lectures/mois incluses, stockage 0,015 $/Go).

## Architecture
- `cdn.afrolookmedia.com/media/<chemin>?alt=media&token=<jeton>` → Worker `afrolook-cdn-router` (code : `docs/cloudflare/afrolook-cdn-router.js`).
  1. lit R2 (compartiment `afrolook-media`, liaison `MEDIA`) si le **jeton du lien** est dans les métadonnées du fichier (`tokens`, copiées de
     Firebase Storage) : lecture partielle (Range), HEAD, ETag/304 gérés, en-tête `x-served-from: r2` ;
  2. sinon repli sur Firebase Storage, comme avant (fichier pas encore copié, jeton absent ou faux : Google refuse alors avec 403).
- **Lecture à travers** : si R2 n'a pas encore le fichier et que Google l'accepte avec le jeton du lien, le Worker le sert **et** le range dans R2
  (`src=worker` dans les métadonnées) : seule la toute première lecture est facturée par Google, même si des milliers de personnes arrivent
  juste après un envoi. Lecture partielle (vidéo) : copie complète lancée en arrière-plan. Au-delà de 40 Mo : la copie périodique s'en charge.
  Jamais de rangement sans jeton, avec un jeton refusé par Google, ni pour une requête HEAD.
- **Copie** : `functions/src/media/r2Mirror.ts` → fonction `r2MirrorSweep` (toutes les 10 min) recopie les fichiers nouveaux ou modifiés
  (même chemin, même jeton) ; chaque nuit à 3 h UTC elle retire de R2 ce qui n'existe plus dans Storage. Clés R2 : `functions/.env`
  (`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, non versionné). Jamais copiés : `test-builds/`, `test_builds/`, `artist_sound_tmp/`, `artist_sounds/`.
- L'application continue d'envoyer vers Firebase Storage (aucune version à publier). Interrupteur : Remote Config `cdn_active`.
- Copie initiale des 15 747 fichiers (25,2 Go) faite le 17 octobre 2026 (0 échec) : script ponctuel, reprenable (saute ce qui existe déjà).

## Mesures du 18 octobre (après la mise en place)
- Sortie de Cloud Storage : ≈ 0,15 Go/h la nuit, ≈ 0,7 Go/h en journée (≈ 10 à 14 Go/jour), contre ≈ 33 Go/jour le 16 octobre.
- 90 liens réels (posts, photos de profil, chroniques) testés : 90 servis par R2 (`x-served-from: r2`).
- Reste chez Google : ≈ 25 % était la **liste complète des fichiers relue toutes les 10 minutes** par `r2MirrorSweep` (≈ 1,2 Mo par page de
  1 000 fichiers, ≈ 3 Go/jour). Corrigé : la liste ne demande plus que le nom et les dates (≈ 5 Ko par page). À grande échelle (centaines de
  milliers de fichiers), remplacer le balayage par un déclencheur `onObjectFinalized` et ne garder le balayage que la nuit.
- Le reste vient de lectures directes (écrans qui n'utilisent pas encore le CDN, anciennes versions, titres complets, lectures partielles annulées).
- Fonctions serveur : ≈ 0,3 $/jour au total (0,17 vCPU par fonction) ; `syncFollowsFromLegacy` représente ≈ 89 % du temps facturé
  (déclenchée à chaque écriture du profil, inutile pour les versions récentes) : à supprimer quand les anciennes versions auront disparu.

## Poids des envois (application, prochaine version)
`lib/services/media_shrink.dart` : images 1600 px max (même format), vidéos 720p ; branché sur tous les envois vers Storage
(sauf stickers et exports du studio).

## Retour arrière
Cloudflare → Workers & Pages → `afrolook-cdn-router` → Déploiements : rétablir la version précédente (l'ancien code est aussi enregistré
dans l'historique des versions du Worker). Sans R2, rien ne casse : le Worker retombe sur Firebase Storage.

## À vérifier dans les jours suivants
- Octets sortant de Cloud Storage (`storage.googleapis.com/network/sent_bytes_count`) : doivent redescendre vers quelques Go/jour.
- Facture : SKU « Cloud Storage Download Worldwide » (Facturation → Rapports).
- Jetons Cloudflare créés pour la mise en place (`afrolook-cache`, `afrolook-worker`) : à supprimer (Mon profil → Jetons API).

## Audit des lectures Firestore (18 octobre, tâche #94, première passe)
Mesure sur 24 h : 553 000 lectures de documents (≈ 5 700 par actif), dont **98,9 % viennent de requêtes et d'écoutes** (seulement 1 % de lectures
de documents isolés). Seulement 4 à 7 connexions actives en moyenne, 15 à 60 écoutes ouvertes.
- **Corrigé côté serveur** : `recalculateScoresOnInteraction` relisait 30 posts (60 pour un post de canal) à chaque vue ou like (1 172 recalculs
  réels par jour ; un post populaire 185 fois). Le score du créateur / du canal n'est plus recalculé que si le score du post a changé d'au moins
  0,25 point et 10 % depuis la dernière propagation (`propagatedScore`, `src/posts/scorePropagation.ts`) ; le calcul du lundi remet tout à jour.
  Gain estimé : 30 000 à 60 000 lectures par jour (6 à 11 %).
- **Corrigé dans l'application (prochaine version)** : les écoutes `getPostsImagesByUser` / `getPostsVideoByUser` (onglets du profil) faisaient une
  requête `Users` par post à chaque changement d'un compteur et accumulaient des doublons ; le profil est lu une fois, la liste reconstruite.
- **À surveiller** : `paymentWatchdog` relit toutes les 15 min les 116 dépôts FeexPay jamais confirmés (≈ 11 000 lectures/jour, 2 %) ; l'écoute
  `GroupChats` de l'accueil sans limite ; la source principale du reste (≈ 400 000 lectures) n'est pas isolée : il faut compter les lectures par
  écran dans l'application (compteur de debug) ou activer les journaux d'accès aux données Firestore pendant une heure.
