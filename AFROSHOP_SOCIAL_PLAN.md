# AfroShop Social — Plan de refonte

> Statut : **EN COURS** · Dernière mise à jour : 2026-08-13
> Branche : `refonte_claude`

---

## Contexte & règles métier

- Les produits existants n'ont que des **images** — la vidéo est optionnelle (rétrocompatibilité totale)
- La vidéo est **prioritaire** dans la création/édition mais non obligatoire
- Si pas de vidéo → afficher la première image dans le feed vidéo et la grille
- **Vidéo max 50 Mo** (côté client avant upload)
- Tout média (vidéo + image) passe par **`convertToCdnUrl()`** dans `authProvider.dart` → `cdn.afrolookmedia.com`
- La vidéo est permise à **tous les niveaux d'abonnement** (GRATUIT inclus)
- Les limites d'abonnement (`nombre_pub`, `nombre_image_pub`) sont **maintenues**
- **Une image de couverture est obligatoire** (thumbnail) — choisie par le vendeur ou auto-générée depuis la vidéo
- Affichage des produits filtré par **pays de l'utilisateur** par défaut — l'utilisateur peut changer
- Tous les filtres existants (catégorie, prix, tri) sont **conservés**

---

## Architecture des données — `ArticleData` (model_data.dart)

### Champs à ajouter

```dart
// Vidéo
String? videoUrl;          // URL CDN vidéo principale (optionnelle)
String? thumbnailUrl;      // Miniature choisie par le vendeur (obligatoire si vidéo)
int?    videoDurationSec;  // Durée en secondes

// Social
int?    commentaires;      // Compteur dénormalisé (source: collection ArticleComments)
List<String>? hashTags;   // ex: ['wax', 'dakar', 'mode']

// Engagement (existant mais à afficher maintenant)
// vues, jaime, contact, partage → DÉJÀ PRÉSENTS, rien à ajouter
```

### Champs existants conservés (ne pas toucher)
- `images`, `vues`, `jaime`, `contact`, `partage`
- `prix`, `prixOriginal`, `reduction`, `negociable`
- `countryData`, `ville`, `quartier`
- `tags`, `sousCategorie`, `categorie_id`
- `booster`, `isBoosted`, `boostEndDate`
- `disponible`, `status`

---

## Nouvelle collection Firestore

```
ArticleComments/
  {commentId}/
    article_id:   String
    user_id:      String
    pseudo:       String
    avatar_url:   String
    text:         String
    createdAt:    Timestamp (serverTimestamp)
    likes:        int (default 0)
```

---

## Fichiers à modifier

### 1. `lib/models/model_data.dart`
- **Action** : Ajouter `videoUrl`, `thumbnailUrl`, `videoDurationSec`, `commentaires`, `hashTags` à `ArticleData`
- Mettre à jour `fromJson` et `toJson`
- **Statut** : ⬜ TODO

### 2. `lib/pages/afroshop/marketPlace/new/addProduit.dart`
- **Action** :
  - Ajouter un `_videoFile` + `_thumbnailUrl` aux variables d'état
  - Afficher le picker vidéo EN PREMIER (priorité visuelle), avec le picker image en dessous
  - Vérification taille max 50 Mo avant upload
  - Upload vidéo → Firebase Storage `videos_article/{filename}` → `convertToCdnUrl()`
  - Sélection thumbnail : frame auto de la vidéo OU image parmi `_mediaFileList`
  - L'image de couverture (thumbnail) est **obligatoire** (validation avant publish)
  - Si pas de vidéo → comportement actuel (images seules)
  - Enregistrer `videoUrl`, `thumbnailUrl`, `videoDurationSec` dans l'article
- **Statut** : ⬜ TODO

### 3. `lib/pages/afroshop/marketPlace/acceuil/home_afroshop.dart`
- **Action** :
  - Ajouter un `TabController` avec 2 onglets : `▶ Vidéos` et `⊞ Grille`
  - Onglet Vidéos → `ShopVideoFeed` (nouveau widget, voir §5)
  - Onglet Grille → affichage actuel (grille + filtres) CONSERVÉ INTÉGRALEMENT
  - Les filtres (pays, catégorie, prix, tri) s'appliquent aux DEUX vues
  - L'onglet Vidéos par défaut
- **Statut** : ⬜ TODO

### 4. `lib/pages/afroshop/marketPlace/acceuil/produit_details.dart`
- **Action** :
  - Si `article.videoUrl != null` → afficher le player vidéo **au-dessus** du carousel d'images
  - Si pas de vidéo → carousel d'images existant uniquement
  - Ajouter section commentaires en bas (bottom sheet ou section inline)
  - Afficher vues, likes, contacts, partages (déjà présents, améliorer l'UI)
  - Afficher les hashtags si présents
- **Statut** : ⬜ TODO

### 5. `lib/pages/afroshop/marketPlace/component.dart` (`ArticleTile` + `ProductWidget`)
- **Action** :
  - Dans la zone image : si `thumbnailUrl != null` → afficher `thumbnailUrl`, sinon `images.first`
  - Si `videoUrl != null` → badge `▶ {durée}` en overlay sur le thumbnail
  - Conserver les badges prix, likes, vues existants
- **Statut** : ⬜ TODO

### 6. `lib/pages/afroshop/marketPlace/modalView/ArticleBottomSheet.dart`
- **Action** : Utiliser `thumbnailUrl ?? images.first` pour l'image dans les cartes
- **Statut** : ⬜ TODO

### 7. `lib/widgets/feed/sections/feed_articles_section.dart`
- **Action** : Idem — `thumbnailUrl ?? images.first`
- **Statut** : ⬜ TODO

---

## Nouveaux fichiers à créer

### 8. `lib/pages/afroshop/marketPlace/acceuil/shop_video_feed.dart`
- **Rôle** : Feed TikTok-style (PageView vertical plein écran)
- **Comportement** :
  - Reçoit la liste `List<ArticleData>` filtrée (même query que la grille)
  - Si article a `videoUrl` → lire la vidéo via CDN
  - Si article n'a PAS de `videoUrl` → afficher `thumbnailUrl ?? images.first` en plein écran (mode image)
  - Actions flottantes à droite : ❤️ like / 💬 commentaires / ↗️ partage / 📞 contacter
  - Info produit en overlay bas : avatar vendeur, titre, prix, hashtags, bouton "Contacter"
  - Scroll infini avec pagination (même logique que `home_afroshop.dart`)
  - Lecture auto muet → son au tap
- **Statut** : ⬜ TODO

### 9. `lib/pages/afroshop/marketPlace/shop_product_comments.dart`
- **Rôle** : Bottom sheet commentaires (même pattern que commentaires posts)
- **Comportement** :
  - Stream `ArticleComments` filtré par `article_id`
  - Champ de saisie + bouton envoyer
  - Likes sur commentaires
  - Compteur dénormalisé → mettre à jour `Articles/{id}.commentaires` à chaque nouveau commentaire
- **Statut** : ⬜ TODO

---

## Règles CDN (à appliquer partout)

```dart
// Dans authProvider.dart — déjà existant
final cdnUrl = convertToCdnUrl(firebaseStorageUrl, appConfig);
```

- Toutes les URLs vidéo et thumbnail doivent passer par `convertToCdnUrl()` après upload
- `appConfig` vient du provider `AppDefaultData` (déjà utilisé ailleurs dans le projet)

---

## Upload vidéo — logique dans `addProduit.dart`

```dart
// Vérification taille
final sizeBytes = await _videoFile!.length();
if (sizeBytes > 50 * 1024 * 1024) {
  // Afficher erreur "Vidéo trop lourde — max 50 Mo"
  return;
}

// Upload
final ref = FirebaseStorage.instance.ref().child('videos_article/${basename(_videoFile!.path)}');
await ref.putFile(File(_videoFile!.path));
final rawUrl = await ref.getDownloadURL();
final cdnUrl = authProvider.convertToCdnUrl(rawUrl, appConfig);
annonceRegisterData.videoUrl = cdnUrl;
```

---

## Règles d'abonnement (inchangées)

| Niveau   | Peut publier | Limite produits | Limite images | Vidéo |
|----------|-------------|-----------------|---------------|-------|
| GRATUIT  | ✅ Oui       | `nombre_pub`    | `nombre_image_pub` | ✅ Oui |
| PREMIUM  | ✅ Oui       | `nombre_pub`    | `nombre_image_pub` | ✅ Oui |
| ADM      | ✅ Illimité  | ∞               | 10            | ✅ Oui |

---

## Ordre d'implémentation recommandé

1. **Modèle** — `model_data.dart` (base pour tout le reste)
2. **addProduit** — upload vidéo + thumbnail
3. **component.dart** — affichage thumbnail/badge vidéo
4. **shop_video_feed.dart** — feed TikTok
5. **home_afroshop.dart** — onglets Video / Grille
6. **produit_details.dart** — player + commentaires
7. **shop_product_comments.dart** — section commentaires
8. **ArticleBottomSheet + feed_articles_section** — thumbnailUrl fallback

---

## Suivi de progression

- [x] 1. model_data.dart — ArticleData enrichi
- [x] 2. addProduit.dart — upload vidéo + thumbnail
- [x] 3. component.dart — badge vidéo + thumbnail (ArticleTile, ArticleTileBooster, ArticleTileSheetBooster, ProductWidget)
- [x] 4. shop_video_feed.dart — nouveau fichier (feed TikTok PageView)
- [x] 5. home_afroshop.dart — onglets Vidéos / Grille
- [x] 6. produit_details.dart — player vidéo + commentaires
- [x] 7. shop_product_comments.dart — nouveau fichier
- [x] 8. ArticleBottomSheet.dart — utilise ProductWidget (déjà corrigé en étape 3)
- [x] 9. feed_articles_section.dart — utilise ProductWidget (déjà corrigé en étape 3)
