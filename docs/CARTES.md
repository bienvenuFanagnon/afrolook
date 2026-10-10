# Studio Cartes Afrolook

Transforme un post (texte, texte + image(s), texte + vidéo) en carte partageable à la signature Afrolook.

## Où l'ouvrir
- Menu « ⋯ » d'un post, ou appui long sur un post → « Créer une carte Afrolook » (`CardEntry.openFromPost`).
- Page de création de post → onglet/mode « Carte » : on crée la carte puis on la publie avec **les règles des posts** (`CardEntry.composeOn` → `UserPostLookImageTab`).
- Tutoriel (`card_tutorial_page.dart`) : entrée « Crée ta carte Afrolook » dans les tutos, exemples faits avec les images de l'application.
- Pas de carte pour les publicités ni pour les posts d'un canal privé (sauf auteur / admin).

## Rendu (`lib/pages/cards/`)
- 4 styles (Kente, Wax, Néon Lagos, Bogolan – Bogolan en Pro), formats portrait 3:2, story 4:5, carré 2:1, export 1080 px.
- Images **jamais coupées** : image entière sur fond flou de la même image ; mises en page mosaïque / polaroïds / bande / unique (4 images max au choix).
- Texte long coupé à la fin d'une phrase + « Lire la suite » (`card_text.dart`).
- Signature Afrolook + QR vers le post (permanents, aucun interrupteur). Vidéo : image de couverture + badge lecture.
- Sorties : enregistrer (galerie, `gal`), partager (`share_plus`), publier en Chronique (`AddChroniquePage`) ou en post.

## Économie (serveur : `functions/src/cards/cards.ts`)
Ordre de `costOf` : admin → Pass Studio → quota du plan → carte d'essai → crédit pub (captures) → pièces.

| | Capture | Publication | Style Pro |
|---|---|---|---|
| Gratuit | 1 essai, puis 25 🪙 ou 1 pub | 10 🪙 | +20 🪙 |
| Premium | 2 / mois | 3 / mois | +20 🪙 |
| Gold | 5 / mois | 20 / mois | +10 🪙 |
| Pass Studio | illimité 30 jours pour 400 🪙 | | |

Tout est réglable dans Firestore `AppConfig/cards` sans mise à jour. Le plan vient de l'abonnement payé (pas de « pubs »). Mois = AAAAMM UTC. La pub « une carte » est l'offre de récompense `card_capture` (masquée de la page Récompenses).

Fonctions : `cardQuote`, `cardCommit`, `cardPassBuy`. Collection `CardUsage` (écriture serveur seulement).

## Non fait / limites connues
- Séries de cartes et opt-out de l'auteur : non implémentés.
- Nouveaux plugins natifs (`gal`, `qr_flutter`) → il faut une vraie version store (pas un patch Shorebird).
- Nouveaux textes pas encore traduits (clés françaises, repli sur le français).
