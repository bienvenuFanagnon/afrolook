# Défis : transformer un post, défi avec une carte, participer avec une carte, annonce élargie

Nécessite une nouvelle version de l'application pour les écrans ; la partie serveur (annonce élargie) agit dès le déploiement des fonctions.

## Transformer un post en défi
- Menu « ⋯ » d'un post (les 4 menus : fil, détails, vidéo, vidéo téléphone) → **« Transformer en défi »**, visible seulement pour l'auteur d'un post ordinaire (texte, image, vidéo, audio ; ni publicité, ni réponse à un défi, ni défi existant) : `DefiConvert.canConvert` (`lib/pages/defi/defi_convert.dart`).
- Page `DefiConvertPage` : aperçu du post, le même formulaire que pour un nouveau défi (`DefiConfigSection` : cagnotte, frais de participation et de vote, nombre de gagnants, date de fin), solde, confirmation, puis l'appel `handleDefiAction` avec l'action **`convert`**.
- Serveur (`functions/src/posts/defiActions.ts`, `handleConvertToDefi`) : mêmes limites que `create` (`parseDefiConfig`), seul l'auteur, post ordinaire et publié, cagnotte débitée dans la même transaction (écriture `TransactionSoldes`), le post devient `type: DEFI` avec `defi_config`, compteurs remis à zéro, `defi_converted_at`. Relance sans effet si le défi existe déjà (pas de second débit).

## Défi avec une carte
- Après la création d'une carte : la feuille « Où publier ta carte ? » du studio propose **« Lancer un défi avec cette carte »** (en plus de la Chronique et du post). Depuis la page de publication (onglet Carte), une feuille « Ta carte est prête » propose « Publier en post » ou « Lancer un défi avec cette carte » (`CardFlow.askPostOrDefi`).
- Le défi passe par l'écran des posts image avec le type « Défi 🏆 » déjà choisi (`UserPostLookImageTab.initialPostType`) : mêmes règles et même création serveur qu'un défi ordinaire.

## Participer à un défi avec une carte
- Bouton « Participer » (`openDefiParticipation`, `lib/pages/defi/defi_ui.dart`) : après les contrôles habituels (déjà inscrit, défi terminé, solde), une feuille propose **« Avec une carte Afrolook »** ou « Avec une photo, une vidéo, un audio ou un texte ». La carte est publiée comme réponse au défi (action `participate`), avec les mêmes règles que les autres participations. Sur le web (pas de studio), le formulaire habituel s'ouvre directement.

## Annonce élargie du lancement (`functions/src/posts/defiBroadcast.ts`)
- Déclenchée côté serveur après `create` et `convert` (jamais bloquante) : notification dans l'application + push OneSignal à **toute la communauté active**, pas seulement aux abonnés.
- Destinataires : abonnés du créateur + comptes actifs ces **60 derniers jours** (`last_time_active`), limités aux pays visés par le post (`availableCountries`, vide ou `ALL` = tous), **5 000 au plus**, jamais l'auteur.
- Garde-fous : un défi n'est annoncé qu'une fois (`defi_broadcast_at` posé dans une transaction) ; l'annonce large est limitée à **une toutes les 6 h par créateur** (`lastDefiBroadcastAt`), au-delà seuls les abonnés sont prévenus.
- `sendBulkNotification` (notification « a posté » envoyée par l'application après publication) ignore désormais les défis déjà annoncés : pas de doublon, y compris avec les anciennes versions de l'application.
- Test : `functions/src/posts/__tests__/defiBroadcast.test.ts`.

## Description modifiable et défis dans le fil
- **Carte depuis un post** : la page de publication reprend la description d'origine du post (modifiable, tronquée à la limite du compte : 300 / 3 000 / 5 000 caractères), avec « Post de @… » pour le post d'un autre. Un bandeau rappelle que la publication crée un NOUVEAU post et ne modifie pas l'ancien (`CardResult.sourcePostId`, `card_flow.dart`).
- **Transformer en défi** (menu d'un post) : la description est modifiable avant le lancement ; l'action `convert` de `handleDefiAction` accepte un champ `description` (texte, 5 000 caractères au plus) appliqué avec la conversion.
- **Défis en cours dans le fil** : `lib/widgets/feed/sections/defi_feed_card.dart`, traités comme des pubs (après les posts 4, 11, 19, puis tous les 12 posts, accueil et fil sport). Un défi différent par emplacement (non participés d'abord, jamais montrés d'abord, les plus proches de la fin en premier), cagnotte, temps restant, bouton Participer ou Voir et voter. Pas de croix : le défi reste visible jusqu'à sa fin. Liste relue au plus toutes les 4 minutes (requête sans index composite).
- Version de l'application : 2.0.8+251, une nouvelle publication sur les stores est nécessaire pour ces changements Flutter.

## Carte « Vote pour moi » (participation à un défi)
- Quand on crée une carte pour **participer à un défi**, un bandeau « Vote pour moi » avec un grand QR code se colle sous la carte (`_VoteBand`, `card_canvas.dart`, hauteur 100 en plus du format choisi). Le QR et le lien mènent au post de participation : `https://afrolookmedia.com/share/post/<id>`.
- L'identifiant du futur post est **réservé dès l'ouverture du studio** (`CardEntry.composeOn` → `presetPostId`), transmis à la page de publication (`UserPostLookImageTab.presetPostId`) puis utilisé comme identifiant du post (la fonction `handleDefiAction`/participate l'accepte : même motif que les identifiants Firestore).
- Onglet « Format » du studio : interrupteur de la mention (activée par défaut) et 4 phrases au choix (Vote pour moi, Soutiens-moi, Je compte sur ton vote, Vote et fais-moi gagner).
- Légende proposée : « 🏆 Vote pour moi ! Je participe au défi sur Afrolook 👉 lien #defiafrolook #carteafrolook » (modifiable).
- Après la publication : feuille « Ta participation est publiée » avec **Partager ma carte** (image + lien, pour WhatsApp, Facebook, TikTok…) et **Copier le lien de mon post**.
- Test : `test/vote_band_test.dart` (taille et absence de débordement du bandeau).

## Aucune monétisation sur les défis ; publicité d'un défi

**Pas de monétisation.** Aucune vue ni aucun like d'un défi (ni d'une participation) n'est monétisé.
- Création et participation : l'option « Post monétisé » est masquée dès que « Défi » est choisi ou qu'on participe à un défi, et le post part toujours avec `monetized: false` (onglets texte, image, vidéo, audio).
- Serveur (`handleDefiAction`) : `sanitizeClientPost` impose `monetized: false` à la création et à la participation, quoi que le client envoie.
- Conversion d'un post existant : refusée si le post est monétisé (champ `monetized` différent de `false`, donc aussi les anciens posts sans choix enregistré) : le choix ne se modifie plus après publication. Le menu « Transformer en défi » est masqué pour ces posts (`DefiConvert.canConvert`) et le serveur refuse avec `POST_MONETIZED`.
- Les 2 défis et les 2 participations existants ont été verrouillés (`monetized: false`).

**Publicité d'un défi (distincte des défis en cours dans le fil).** Le créateur d'un défi en cours, avec image ou vidéo, le booste depuis « Booster ce post » (`boostPageFor` → `DefiBoostPage`) : durée au même tarif que les publicités, pays, texte, paiement en pièces (`kind: 'ad'`), validation par l'équipe. Le post reste un défi (jamais transformé en publicité). Une `Advertisement` est créée avec `postId` = le défi, `actionType: 'defi'`, bouton « Participer » ; elle circule dans le même circuit que les publicités Afrolook (rotation partagée). Le bouton ouvre le défi dans l'application (`AdActions.open`, utilisé par tous les écrans de publicité) ; la publicité n'est plus diffusée quand le défi est terminé (`loadAdvertisements`).
