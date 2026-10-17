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
