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
