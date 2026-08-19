# Plan — Refonte des cartes publicitaires entités (Profil / Canal / Groupe)

## Contexte

L'application Afrolook gère deux types de boosts publicitaires :
- **Boost post** → format bannière horizontale (existant, à conserver tel quel)
- **Boost entité** (profil, canal, groupe) → nouveau format carte verticale à implémenter

Le widget actuel `AfrolookInlineAd` (`lib/pages/pub/afrolook_inline_ad.dart`) affiche les deux types mais avec le même format bannière horizontale pour les entités — ce qui est incorrect. Il faut créer un format visuel distinct pour chaque type d'entité.

---

## Design à implémenter

### Format bannière horizontale (post) — INCHANGÉ

Conserver `_buildPostBanner(...)` tel quel :
- Miniature 110×110 px à gauche
- Texte titre + ligne profil créateur + bouton CTA à droite
- Badge "Sponsorisé | Post" en haut à gauche

### Format carte verticale (entité) — NOUVEAU

Remplacer `_buildEntityBoostBanner(...)` par une logique qui choisit le bon format selon `ad.ownerType` :

```
'user'  → _buildProfileCard(ad)
'canal' → _buildCanalCard(ad)
'group' → _buildGroupCard(ad)
```

#### Structure commune aux 3 cartes verticales

```
┌─────────────────────────────┐
│ [ZONE VISUELLE] (voir détail│
│ par type ci-dessous)        │
├─────────────────────────────┤
│     Nom entité (Syne bold)  │
│   N abonnés / N membres     │
├─────────────────────────────┤
│ [mini] [mini] [mini]        │  ← 3 derniers posts (ownerRecentPosts)
├─────────────────────────────┤
│  [ Bouton CTA animé (bounce)│
└─────────────────────────────┘
│ Ne plus voir de pubs → Premium (lien)
```

#### Zone visuelle par type

**Profil (`_buildProfileCard`) :**
- Avatar circulaire centré 76×76 px avec bordure `Color(0xFFFFD700)` (3px)
- Si pas d'avatar : icône `Icons.person` sur fond `Color(0xFF7A5A9E)`
- Pas de cover/bandeau

**Canal (`_buildCanalCard`) :**
- Bandeau cover pleine largeur, hauteur 78px, couleur de fond `Color(0xFF1C4A6E)` (ou cover image si disponible)
- Logo canal : Rectangle arrondi (borderRadius 11px) 52×52 px, centré, chevauchant le bas du bandeau (offset `-24px`)
- Bordure blanche 3px autour du logo (couleur `colors.cardBackground`)

**Groupe (`_buildGroupCard`) :**
- Même bandeau cover que canal, couleur `Color(0xFF3D2560)`
- Icône groupe : Cercle 52×52 px (border-radius 50%) centré, chevauchant le bas (offset `-24px`)
- Bordure blanche 3px

#### Badges "Sponsorisé" (sur toutes les cartes)

- Position : `Positioned(top: 8, left: 12)` sur le Stack de la zone visuelle
- Contenu : badge doré "Sponsorisé" + badge accent type ("Créateur" / "Canal" / "Groupe")
- Icône info `Icons.info_outline` en `Positioned(top: 8, right: 12)`

Pour le profil (pas de bandeau), la ligne de badges est dans un `Padding` classique en haut de la carte.

#### Mini-posts grid

- `Row` avec 3 `Expanded` enfants
- Chaque cellule : `AspectRatio(1)` + `ClipRRect(borderRadius: 4)` + `CachedNetworkImage` + overlay noir `0.35` opacity
- Icône play si `isVideo == true`
- Si `ownerRecentPosts` est vide ou null : ne pas afficher la section (ou afficher 3 placeholders gris)
- Source : `ad.ownerRecentPosts` (liste de maps `{'thumb': String, 'isVideo': bool}`)

#### Bouton CTA (bounce animé)

```dart
// Animation controller dans le State widget ou via AnimationController
// Keyframes :
// 0%   → translateY(0) scale(1)
// 7%   → translateY(-9) scale(1.06)
// 13%  → translateY(-2) scale(1.02)
// 17%  → translateY(-6) scale(1.04)
// 22%  → translateY(0) scale(1)
// 22–100% → rien (pause)
// Durée totale : 4 secondes, repeat infini
```

Label du bouton selon `ad.ownerType` :
- `'user'`  → "Suivre" + icône `Icons.person_add`
- `'canal'` → "S'abonner" + icône `Icons.notifications_none`
- `'group'` → "Rejoindre" + icône `Icons.login`

Couleur : fond `Color(0xFFFFD700)`, texte `Color(0xFF5a3d00)`, `FontWeight.w800`, `borderRadius: 30`

Au tap : enregistrer le click (`_recordClick(ad)`) puis naviguer vers l'entité via `_navigateToAdOwner(context, ad)`.

---

## Bug à corriger : description affichée

### Problème actuel

Dans `_buildEntityBoostBanner` et dans `_buildMidrollCard` de `post_video_format_tel_details.dart`, la description affichée est :

```dart
ad.ownerDescription  // ← "à propos" de l'utilisateur/canal/groupe
```

Ce n'est **pas** la description saisie lors de la création de la pub.

### Correction

La description publicitaire est stockée dans Firestore sous le champ `description` de l'annonce, mais elle n'est pas incluse dans le JSON qui alimente `auth.advertisements`.

**Étape 1 — `lib/providers/authProvider.dart`, méthode `loadAdvertisements()`**

Lors de la construction de `tempAds`, inclure le champ `description` de l'annonce dans le JSON :

```dart
// Pour les entity boosts :
final adJson = ad.toJson();
adJson['adDescription'] = adDoc.data()?['description'] as String? ?? '';
tempAds.add({'ad': adJson, 'isEntityBoost': true});

// Pour les post boosts :
final adJson = ad.toJson();
adJson['adDescription'] = adDoc.data()?['description'] as String? ?? '';
tempAds.add({'ad': adJson, 'post': post.toJson()});
```

> Note : utiliser la clé `'adDescription'` dans le JSON intermédiaire pour éviter la collision avec le champ `description` du post.

**Étape 2 — Dans les widgets d'affichage**

Remplacer partout `ad.ownerDescription` utilisé comme texte de description publicitaire par :

```dart
final adDescription = _adData?['adDescription'] as String? ?? '';
// ou dans _buildMidrollCard :
final adDescription = adData?['adDescription'] as String? ?? '';
```

Ne **pas** afficher `ad.ownerDescription` comme description de pub. Ce champ (`ownerDescription`) peut rester pour les "N abonnés" ou d'autres metadata internes, mais ne doit **jamais** apparaître comme corps de texte publicitaire dans le feed ou le midroll.

---

## Fichiers à modifier

| Fichier | Changements |
|---|---|
| `lib/pages/pub/afrolook_inline_ad.dart` | Remplacer `_buildEntityBoostBanner` par 3 méthodes card + animation bounce |
| `lib/providers/authProvider.dart` | Inclure `adDescription` dans le JSON `tempAds` |
| `lib/pages/post_video_format_tel_details.dart` | `_buildMidrollCard` : utiliser `adDescription` au lieu de `ownerDescription`; pour entity boosts, afficher la card verticale (ou une version simplifiée du même format) |

---

## Fichiers de référence à lire avant de coder

- `lib/pages/pub/afrolook_inline_ad.dart` — widget actuel complet
- `lib/providers/authProvider.dart` — méthode `loadAdvertisements()` (lignes ~112–151)
- `lib/models/model_data.dart` — classe `Advertisement` (champs disponibles)
- `lib/pages/post_video_format_tel_details.dart` — méthode `_buildMidrollCard` (chercher ce nom)
- `lib/theme/app_colors.dart` — `AppColors.of(context)` pour les couleurs thème

---

## Contraintes importantes

- Ne **jamais** utiliser `userData` — toujours `loginUserData` via le provider auth
- Ne **jamais** afficher les 25% de commission Afrolook dans l'UI
- Utiliser `AppColors.of(context)` pour toutes les couleurs thème (pas de hardcode sauf les constantes dorées `0xFFFFD700`, `0xFFFF8C00`)
- L'animation bounce doit respecter `prefers-reduced-motion` : si la préférence système est activée, désactiver l'animation
- Les navigations vers les entités passent par les méthodes existantes :
  - `CanalDetails(canal: Canal.fromJson(data))` pour les canaux
  - `GroupInfoPage(groupId: id, groupName: name)` pour les groupes
  - `OtherUserPage(otherUser: UserData.fromJson(data))` pour les profils
- La méthode `_navigateToAdOwner(BuildContext context, Advertisement ad)` dans `afrolook_inline_ad.dart` gère déjà ce routing — la réutiliser

---

## Comportement si données manquantes

| Donnée manquante | Comportement attendu |
|---|---|
| `ownerAvatar` null/vide | Afficher icône placeholder colorée (couleur par type) |
| `ownerRecentPosts` null/vide | Masquer la section mini-posts complètement |
| `ownerFollowers` null/0 | Masquer la ligne abonnés/membres |
| `ownerName` null/vide | Ne pas afficher la carte du tout (`SizedBox.shrink()`) |

---

## Ordre d'implémentation recommandé

1. Corriger le bug `adDescription` dans `authProvider.dart`
2. Créer `_buildProfileCard`, `_buildCanalCard`, `_buildGroupCard` dans `afrolook_inline_ad.dart`
3. Mettre à jour `_buildEntityBoostBanner` pour router vers la bonne méthode selon `ownerType`
4. Ajouter l'`AnimationController` avec les keyframes bounce dans le `State`
5. Corriger `_buildMidrollCard` dans `post_video_format_tel_details.dart` pour utiliser `adDescription`
6. Tester en mode clair et sombre
