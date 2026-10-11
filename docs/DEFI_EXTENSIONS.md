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
