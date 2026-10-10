# Studio Cartes Afrolook

Transforme un post (texte, texte + image(s), texte + vidéo) en carte partageable à la signature Afrolook.

## Où l'ouvrir
- Menu « ⋯ » d'un post, ou appui long sur un post → « Créer une carte Afrolook » (`CardEntry.openFromPost`).
- Page de création de post → onglet/mode « Carte » : on crée la carte puis on la publie avec **les règles des posts** (`CardEntry.composeOn` → `UserPostLookImageTab`).
- Tutoriel (`card_tutorial_page.dart`) : entrée « Crée ta carte Afrolook » dans les tutos, exemples faits avec les images de l'application.
- Pas de carte pour les publicités ni pour les posts d'un canal privé (sauf auteur / admin).

## Rendu (`lib/pages/cards/`)
- **26 styles** en 4 familles (`CardPack`) : *Héritage* (Kente, Wax, Bogolan), *Moderne* (Néon, Glass, Pro, Manga, Anime, Magazine, Collector, Sport, Gamer, Y2K, Street), *Drapeaux* (Drapeau, Passeport, Timbre, Supporter, Duo, Fierté), *Idées* (Film, Journal, Musique, Embarquement, Tarot, Citation).
- Gratuits : Kente, Wax, Néon, Glass, Pro. Tous les autres sont « Pro » (+20 🪙, Gold +10, inclus avec le Pass).
- Architecture : `card_canvas.dart` (squelette commun : en-tête, texte, média, pied QR + sceau), `card_looks.dart` (couleurs, polices, fond, panneau de chaque style), `card_layouts.dart` (mises en page propres : Manga, Collector, Passeport…), `card_painters.dart` (fonds dessinés à la main). Un nouveau style = une entrée dans `_lookOf` / `_layoutLooks` + un nom dans `CardStyleId`.
- Les mises en page n'utilisent que des proportions (`Expanded`) : elles s'adaptent aux trois formats (portrait 4:5, story 9:16, carré).
- Images **jamais coupées** : image entière sur fond flou de la même image ; mosaïque / polaroïds / bande / unique (4 images max au choix).
- Texte long coupé à la fin d'une phrase + « Lire la suite » (`card_text.dart`).
- **Drapeaux** (`card_flags.dart`) : dessins du paquet `country_flags` (266 pays). Pays par défaut = pays du profil de l'auteur ; le studio propose un sélecteur (et un second pays pour Duo). Sans pays connu : Togo.
- **Statistiques** : « J'aime · commentaires » (activé) et « Abonnés » (désactivé par défaut). Chaque style les place à son endroit naturel avec son vocabulaire (ATQ/DÉF/PV du Collector, « tirage » du Journal et du Timbre, XP du Gamer, « visas » du Passeport…).
- **Signature** non retirable : coin plié, bande tricolore, sceau « Créé par afrolook » et **QR obligatoire** (post d'origine, sinon profil du créateur `/share/creator/{id}`, sinon accueil).
- Vidéo : image de couverture + badge lecture.
- Sorties : enregistrer (galerie, `gal`), partager (`share_plus`), publier en Chronique (`AddChroniquePage`) ou en post.

## Économie (serveur : `functions/src/cards/cards.ts`)
Ordre de `costOf` : admin → Pass Studio → quota du plan (le gratuit a 1 capture par mois) → carte d'essai (0 par défaut) → crédit pub (captures) → pièces.

| | Capture | Publication | Style Pro |
|---|---|---|---|
| Gratuit | 1 par mois offerte (après une pub récompensée ; sans pub si aucune n'est disponible), puis 25 🪙 ou 1 pub | 10 🪙 | +20 🪙 |
| Premium | 2 / mois | 3 / mois | +20 🪙 |
| Gold | 5 / mois | 20 / mois | +10 🪙 |
| Pass Studio | illimité 30 jours pour 400 🪙 | | |

Tout est réglable dans Firestore `AppConfig/cards` sans mise à jour. Le plan vient de l'abonnement payé (pas de « pubs »). Mois = AAAAMM UTC. La pub « une carte » est l'offre de récompense `card_capture` (masquée de la page Récompenses).

Fonctions : `cardQuote`, `cardCommit`, `cardPassBuy`. Collection `CardUsage` (écriture serveur seulement).

## Non fait / limites connues
- Séries de cartes et possibilité pour un auteur de refuser que ses posts deviennent des cartes : non implémentés.
- Nouveaux plugins natifs (`gal`, `qr_flutter`) et nouvelles polices → il faut une vraie version store (pas un patch Shorebird).
- Nouveaux textes pas encore traduits (clés françaises, repli sur le français) ; noms de pays en anglais (liste de `country_code_picker`).
- Site web de création de cartes : prévu plus tard ; les QR passent par `afrolookmedia.com/share/…`, donc il pourra reprendre ces liens.
