# Stickers Afrolook — spécification technique

Proposition validée : https://claude.ai/artifact/Rpv8f1UVq1rPh6RrJCwtD3 (catalogue : https://claude.ai/artifact/WWZvan7dXMrDeKP6ESm3GA).
Tout est payé en pièces. Le serveur décide : l'app ne fait que pré-vérifier et afficher.

## Règles métier (déjà écrites dans `regles_confidentialite_page.dart`)
- Compte gratuit : aucun sticker/média en commentaire (bouton visible avec le signe PREMIUM).
- Premium : 1 sticker/média par post et par utilisateur, 5 par jour. Gold : 3 par post, 10 par jour. Admin (role == 'ADM') : traité comme Gold.
- Poids : image ≤ 300 Ko, animation ≤ 600 Ko, boucle ≤ 3 s, sans son.
- Pack payant : ne s'utilise que s'il est acheté. Sticker-cadeau : débité en pièces (phase 4).
- Stickers personnels (« Mes stickers ») : Premium 10, Gold 50.
- Partage : pack payant 70 % créateur / 30 % Afrolook ; sticker-cadeau 40 % auteur du commentaire / 30 % créateur du sticker / 30 % Afrolook.

## Abonnement (lecture serveur)
`Users/{uid}.abonnement` = `{type:'gratuit'|'premium'|'gold', dateFin: ISO string, estActif: bool}`. Actif si `type` ∈ {premium, gold}, `estActif != false` et `dateFin` > maintenant. `role == 'ADM'` ⇒ gold.

## Collections Firestore
- `StickerPacks/{packId}` : `name` (fr), `names` {fr,en,es,de,ar,pt,zh,sw}, `kind` 'official'|'creator'|'world', `region` ('universal'|'africa'|'caribbean'|'europe'|'asia'|'latam'|'mena'), `creatorId` ('afrolook' pour l'officiel), `priceCoins` (0 = gratuit), `status` 'active'|'pending'|'rejected'|'removed', `stickerCount`, `order`, `coverUrl`, `createdAt`, `updatedAt` (ms).
- `Stickers/{stickerId}` : `packId`, `order`, `category` (joie, reussite, compliments, amour, surprise, taquinerie, soutien, colere, reponses, contenus, fetes, sport, musique, afrolook, humeur), `captions` {fr,en,es,de,ar,pt,zh,sw} (facultatif : sticker sans mot), `keywords` [minuscules, sans accents, toutes langues], `url` (WebP animé), `thumbUrl` (image fixe), `storagePath`, `sizeBytes`, `durationMs`, `animated`, `giftPriceCoins` (0 = sticker normal, > 0 = sticker-cadeau), `status`, `creatorId`, `createdAt`.
- `UserStickers/{id}` (phase 3) : `ownerId`, `url`, `thumbUrl`, `storagePath`, `sizeBytes`, `durationMs`, `captions` (facultatif), `status`, `createdAt`.
- `StickerOwnership/{uid}_{packId}` (serveur) : `userId`, `packId`, `priceCoins`, `purchasedAt`.
- `StickerUsage/{uid}_{yyyymmdd UTC}` (serveur) : `userId`, `day`, `count`.
- `Users/{uid}/StickerRecents/{stickerId}` (serveur écrit, propriétaire lit) : `lastUsedAt` (ms), `source` 'pack'|'mine'. Le serveur garde les 12 plus récents.
- `PostComments/{id}` : nouveau champ facultatif `media` = `{type:'sticker'|'user_sticker'|'image', stickerId?, url, thumbUrl?, w, h, sizeBytes, animated}` ; `message` peut être vide si `media` est présent.

## Appels serveur (Cloud Functions, région us-central1)
- `stickerAccess({postId?})` → `{tier, canSend, reason, perPostMax, perDayMax, dayUsed, postUsed, recents:[{stickerId, source, usable, reason}]}`. `reason` ∈ null | 'not_subscribed' | 'suspended' | 'day_limit' | 'post_limit' | 'not_owned' | 'inactive' | 'removed' | 'no_coins'.
- Trigger `onCommentMediaCreated` sur `PostComments/{id}` : si `media` est présent, vérifie abonnement, limites (par post, par jour), poids déclaré, sticker actif, pack acheté ; en cas d'échec, supprime le commentaire ; sinon incrémente `StickerUsage` et met à jour `StickerRecents`.
- (phase 4) `stickerPackPurchase({packId})`, `stickerGiftSend({commentId, stickerId})`, `submitStickerPack`, page admin de modération.

## Fichiers Storage
- `stickers/{packId}/{stickerId}.webp` et `..._thumb.webp` : écrits par le serveur ou l'admin.
- `user_stickers/{uid}/{id}.webp` : écrits par le propriétaire (≤ 600 Ko).
- `comment_media/{uid}/{commentId}.webp` : images de commentaire (≤ 300 Ko).
Lecture réservée aux utilisateurs connectés. Aucun lien public dans un commentaire autre que l'URL stockée dans `media`.

## Ajouts phases 3 et 4 (serveur déjà écrit)
- `payWithCoins` avec `kind: 'sticker_pack'` et `refId: packId` : achat d'un pack payant (70 % créateur, 30 % Afrolook, parrainages inclus). Crée `StickerOwnership/{uid}_{packId}`. Erreur `already-exists` si le pack est déjà possédé. Le prix affiché vient de `StickerPacks.priceCoins`. L'app utilise `CoinCheckout.pay(context, kind: 'sticker_pack', label: …, coins: priceCoins, refId: packId)` (lib/services/coin_checkout.dart).
- `stickerGiftSend({commentId, replyId?, stickerId})` : sticker-cadeau (sticker dont `giftPriceCoins > 0`), ouvert à tous les comptes, débité en pièces, 40 % auteur du commentaire / 30 % créateur du sticker / 30 % Afrolook. Écrit un doc `CommentGifts` avec `stickerId`, `stickerUrl`, `stickerThumbUrl`. Erreur `resource-exhausted` = solde insuffisant (ouvre `CoinCheckout.insufficient`).
- `UserStickers/{id}` (Mes stickers) : le client envoie le fichier dans `user_stickers/{uid}/{id}.webp` (≤ 600 Ko, image/webp ou image/gif) puis crée le doc `{ownerId, storagePath, url, thumbUrl, createdAt, captions?}` ; `onUserStickerCreated` valide (quota Premium 10 / Gold 50, poids) et passe `status` à 'active' (ou supprime le doc). Envoi en commentaire : `media.type = 'user_sticker'`, `media.stickerId = id UserStickers`.
- `convertStickerVideo({path})` (à venir) : le client envoie une vidéo courte (≤ 3 s, ≤ 3 Mo) dans `sticker_video_uploads/{uid}/…mp4` puis appelle ce callable ; il la convertit en WebP animé, crée le `UserStickers` et renvoie `{stickerId}`.
- `submitStickerPack({name, region, priceCoins, stickers:[{path, category, captions, keywords, giftPriceCoins}]})` : le créateur envoie d'abord 4 à 24 fichiers dans `sticker_submissions/{uid}/{fichier}` (≤ 600 Ko, 128 à 1024 px), puis appelle ce callable. Éligibilité : Premium/Gold et compte de plus de 30 jours (ou vérifié) ; 3 packs en attente maximum. Copie exacte refusée (erreur `already-exists`), copie proche ⇒ `needsReview: true`. Le pack est créé en `status: 'pending'`.
- `adminStickerAction({packId?|stickerId?, action:'approve'|'reject'|'remove'|'restore', reason?})` : modération (admin uniquement, journalisée dans `AdminActions`, notifie le créateur).
- `reportStickerCopy({stickerId, note?})` : crée `StickerReports/{id}` `{stickerId, packId, creatorId, reporterId, note, status:'open', createdAt}`.
- Champs supplémentaires : `StickerPacks.needsReview`, `rejectReason`, `salesCount` ; `Stickers.copyOf`, `copyOfCreator`, `usageCount`, `giftCount`, `sha256`, `dhash` (ne pas afficher).
