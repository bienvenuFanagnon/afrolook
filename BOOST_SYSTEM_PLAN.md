# Système Boost Afrolook — Plan de travail

> **Statut** : Décisions confirmées — implémentation en cours  
> **Dernière mise à jour** : 2026-08-19  
> **Branche de travail** : `refonte_claude`

## Décisions confirmées (2026-08-19)

| Question | Décision |
|---|---|
| Notification groupées (style accordéon) | ✅ Validé — à implémenter |
| Boost profil/canal → approbation admin ? | ✅ Oui, même flux que les pubs post (status `pending` → admin → `active`) |
| Boost profil/canal → même ciblage géo ? | ✅ Oui, même sélecteur de pays que `UserCreateAdvertisementPage` |

---

## Vue d'ensemble

Le système Boost permet aux créateurs de promouvoir **un post**, **leur profil** ou **un canal** auprès de leur communauté (quartier → ville → pays → au-delà). Les publicités apparaissent dans le feed, les bannières inline (`AfrolookInlineAd`) et les modales midroll.

---

## Architecture actuelle (base de départ)

### Collections Firestore existantes
| Collection | Usage actuel |
|---|---|
| `Posts` | Posts normaux + posts marqués `isAdvertisement: true` |
| `Advertisements` | Campaigns post-boost liées à un `postId` |
| `active_boosts` (Afroshop) | Boost produits Afroshop (séparé) |

### Fichiers clés
| Fichier | Rôle |
|---|---|
| `lib/pages/pub/afrolook_inline_ad.dart` | Bannière pub 72×72 dans les feeds |
| `lib/pages/post_video_format_tel_details.dart` | Feed vidéo vertical + midroll overlay |
| `lib/pages/postDetailsVideo.dart` | Page détails vidéo paysage — midroll à ajouter |
| `lib/pages/contenuPayant/widgets/boost_modal.dart` | Modal boost contenu payant (référence tarifs) |
| `lib/models/model_data.dart` | Modèle `Advertisement`, `Post`, `Canal`, `UserData` |
| `lib/providers/authProvider.dart` | Charge `auth.advertisements` (liste des pubs actives) |

### Flux actuel d'une pub post
```
Firestore Advertisements (active, status=active)
  → authProvider.advertisements (chargé au login)
    → AfrolookInlineAd._pickAd() (aléatoire, évite répétition)
      → Rendu bannière 72×72 (image/vidéo + caption + CTA)
        → Midroll overlay si vidéo ≥ 20s (15s avant la fin)
```

---

## Nouvelles fonctionnalités à implémenter

### F1 — Profil du créateur visible dans les pubs

**Objectif** : Dans toute pub (bannière 72×72 et modal midroll), afficher le profil du créateur (avatar, pseudo, abonnés) avec un bouton **"Suivre"** ou **"S'abonner au canal"** si l'utilisateur ne le suit pas encore.

**Données nécessaires dans `Advertisements`** :
```dart
// Ajouter au modèle Advertisement (model_data.dart) :
String? ownerType;      // 'user' | 'canal'
String? ownerId;        // userId ou canalId
String? ownerName;      // Pseudo ou nom du canal
String? ownerAvatar;    // URL photo de profil / logo canal
int? ownerFollowers;    // Nb abonnés au moment du boost (snapshot)
String? ownerCanalId;   // Si le post appartient à un canal
```

**Rendering** :
- Bannière 72×72 : ligne de profil compacte sous la miniature (avatar 20px + pseudo + mini bouton "Suivre")
- Midroll modal : section profil en bas de card (avatar 44px + pseudo + nb abonnés + bouton "Suivre" ou "S'abonner au canal")
- Le bouton vérifie `auth.loginUserData?.followingList?.contains(ownerId)` pour l'état initial

**Fichiers à modifier** :
- [ ] `lib/models/model_data.dart` → ajouter champs `ownerType`, `ownerId`, `ownerName`, `ownerAvatar`, `ownerFollowers` à `Advertisement`
- [ ] `lib/pages/pub/afrolook_inline_ad.dart` → ajouter widget profil compact dans la bannière
- [ ] `lib/pages/post_video_format_tel_details.dart` → ajouter section profil dans `_buildMidrollCard()`
- [ ] `lib/pages/postDetailsVideo.dart` → idem (midroll à créer — voir F4)

---

### F2 — Boost de profil utilisateur (nouveau type)

**Objectif** : Un utilisateur peut booster son **profil** (pas un post) pour être mis en avant auprès de sa communauté.

#### F2a — Nouvelle collection Firestore `ProfileBoosts`
```
ProfileBoosts/{boostId}
  type:         "profile"
  ownerId:      userId
  ownerName:    string
  ownerAvatar:  string
  ownerBio:     string (tronqué 120 chars)
  ownerFollowers: int (snapshot)
  ownerPostsCount: int
  boostDays:    int (7, 14, 30, 90, 180, 365)
  boostCost:    int (FCFA)
  startDate:    timestamp
  endDate:      timestamp
  status:       "pending" | "active" | "expired"
  isPaid:       bool
  views:        int
  follows:      int  ← nb de follows générés par ce boost
  viewersIds:   [userId]
  followersIds: [userId]
```

#### F2b — Tarifs profil seul
Identiques aux post-boosts :
| Durée | Prix |
|---|---|
| 7 jours | 1 000 FCFA |
| 14 jours | 1 800 FCFA |
| 1 mois | 3 500 FCFA |
| 3 mois | 9 000 FCFA |
| 6 mois | 16 000 FCFA |
| 12 mois | 28 000 FCFA |

#### F2c — Point d'entrée UI
- Bouton "Booster mon profil" sur la **page profil utilisateur** (`lib/pages/user/otherUser.dart` ou page propre)
- Ouvre `ProfileBoostModal` (nouveau widget, même structure que `BoostModal`)

**Fichiers à créer/modifier** :
- [ ] `lib/pages/user/widgets/profile_boost_modal.dart` (nouveau)
- [ ] `lib/pages/user/userProfile.dart` → ajouter bouton "Booster mon profil"
- [ ] Cloud Function `secureProfileBoost` (nouveau, côté serveur) — paiement + création `ProfileBoosts`

---

### F3b — Boost de groupe de chat (nouveau type)

**Objectif** : Promouvoir un groupe de chat pour recruter des membres, au même titre qu'un canal ou un profil.

**Collection Firestore** : `GroupBoosts/{boostId}`
```
type:              "group"
ownerId:           userId (créateur du groupe)
groupId:           string
groupName:         string
groupAvatar:       string
groupDescription:  string
groupMembersCount: int (snapshot)
boostDays, boostCost, startDate, endDate, status, isPaid (identique aux autres)
views, joins (nb de membres recrutés par ce boost), viewersIds, joinersIds
targetCountries:   [] (même sélecteur que UserCreateAdvertisementPage)
```

**Rendu dans les pubs** :
- Bannière inline : avatar groupe + nom + "Rejoindre"
- Midroll : carte groupe avec description + nb membres + bouton "Rejoindre le groupe"

**Point d'entrée UI** : Page détails du groupe de chat (visible pour le créateur) → "Booster ce groupe"

**Fichiers à créer/modifier** :
- [ ] `lib/pages/chat/widgets/group_boost_modal.dart` (nouveau)
- [ ] Page détails groupe → bouton "Booster ce groupe"
- [ ] Cloud Function `secureGroupBoost` (nouveau)
- [ ] `ownerType` dans `Advertisement` → ajouter valeur `'group'`

> Même tarifs, même approbation admin, même ciblage géo que les autres boost types.

---

### F3 — Boost de canal (nouveau type)

**Objectif** : Le propriétaire d'un canal peut booster son **canal** pour attirer de nouveaux abonnés.

#### F3a — Nouvelle collection Firestore `CanalBoosts`
```
CanalBoosts/{boostId}
  type:         "canal"
  ownerId:      userId (propriétaire)
  canalId:      string
  canalName:    string
  canalAvatar:  string
  canalBio:     string
  canalSubscribers: int (snapshot)
  canalPostsCount:  int
  boostDays, boostCost, startDate, endDate, status, isPaid
  views, subscriptions (nb d'abonnements générés), viewersIds, subscribersIds
```

#### F3b — Point d'entrée UI
- Bouton "Booster ce canal" sur la **page détails canal** (`lib/pages/canaux/detailsCanal.dart`)
- Visible uniquement pour le propriétaire du canal
- Ouvre `CanalBoostModal` (nouveau widget)

**Fichiers à créer/modifier** :
- [ ] `lib/pages/canaux/widgets/canal_boost_modal.dart` (nouveau)
- [ ] `lib/pages/canaux/detailsCanal.dart` → ajouter bouton propriétaire
- [ ] Cloud Function `secureCanalBoost` (nouveau)

---

### F4 — Boost combiné (post + profil/canal)

**Objectif** : Lors du boost d'un post, proposer d'y associer le profil ou le canal de l'auteur pour un effet maximal. Le montant augmente.

#### F4a — Tarifs combinés
| Durée | Post seul | Post + Profil/Canal |
|---|---|---|
| 7 jours | 1 000 FCFA | 1 500 FCFA (+50%) |
| 14 jours | 1 800 FCFA | 2 700 FCFA (+50%) |
| 1 mois | 3 500 FCFA | 5 200 FCFA (+49%) |
| 3 mois | 9 000 FCFA | 13 500 FCFA (+50%) |
| 6 mois | 16 000 FCFA | 24 000 FCFA (+50%) |
| 12 mois | 28 000 FCFA | 42 000 FCFA (+50%) |

> **Règle** : Si le post vient d'un canal, le combiné associe automatiquement le **canal** (pas le profil personnel).

#### F4b — UI dans la page boost
Après avoir sélectionné la durée, afficher un toggle :
```
[ ] Ajouter aussi mon profil/canal (+500 FCFA/sem)
```
- Si coché → prix augmente en temps réel
- Si le post appartient à un canal → "Ajouter aussi le canal [nom]"
- Si post personnel → "Ajouter aussi mon profil"

#### F4c — Données créées
En cas de boost combiné, créer **deux documents** dans Firestore :
1. `Advertisements/{id}` → boost du post (avec flag `combinedWith: profileBoostId`)
2. `ProfileBoosts/{id}` OU `CanalBoosts/{id}` → boost profil/canal (avec flag `combinedWith: adId`)

**Fichiers à modifier** :
- [ ] Page boost post (à créer — voir F6) → ajouter section toggle combiné
- [ ] Cloud Function `secureBoostPost` → gère le combiné (crée 2 docs en transaction)

---

### F5 — Affichage des pubs profil/canal dans le feed

**Objectif** : Les `ProfileBoosts` et `CanalBoosts` actifs apparaissent dans le feed (bannière inline et midroll), mélangés aléatoirement avec les pubs post.

#### F5a — Chargement dans `authProvider`
```dart
// Charger en parallèle des advertisements :
List<Map<String, dynamic>> profileBoostAds = [];  // nouveau

// Query :
FirebaseFirestore.instance
  .collection('ProfileBoosts')
  .where('status', isEqualTo: 'active')
  .where('endDate', isGreaterThan: now)
  .limit(20)
  .get()
```
Convertir chaque `ProfileBoost` en format compatible `{type: 'profile', data: ...}` et `{type: 'canal', data: ...}`.

#### F5b — `_pickAd()` dans `AfrolookInlineAd`
```dart
// Pool mixte : 70% post-ads + 30% profil/canal boosts
final allAds = [
  ...auth.advertisements.map((a) => {'kind': 'post', ...a}),
  ...auth.profileBoostAds.map((a) => {'kind': 'profile', ...a}),
];
// Sélection aléatoire pondérée
```

#### F5c — Rendu bannière profil boost (72×72)
```
┌──────────────────────────────────────────────┐
│ [Avatar 72×72]  Nom du créateur / canal      │
│                 "Sponsorisé · Profil"        │
│                 [Suivre / S'abonner]  ►      │
└──────────────────────────────────────────────┘
```

#### F5d — Rendu midroll profil boost (grand modal)
```
┌─────────────────────────────────┐
│ [Photo de couverture / gradient]│
│                                 │
│  [Avatar 64px]  Nom Créateur    │
│  "123 abonnés · 45 posts"      │
│                                 │
│  Bio courte du créateur…        │
│                                 │
│  [   S'abonner au canal   ]     │
│  [       Voir le profil    ]    │
│                      [Fermer]   │
└─────────────────────────────────┘
```

**Fichiers à modifier** :
- [ ] `lib/providers/authProvider.dart` → ajouter chargement `ProfileBoosts` + `CanalBoosts`
- [ ] `lib/pages/pub/afrolook_inline_ad.dart` → `_buildProfileBoostBanner()` + rendu conditionnel
- [ ] `lib/pages/post_video_format_tel_details.dart` → `_buildMidrollProfileCard()` + sélection mixte dans `_showMidrollOverlay()`

---

### F6 — Page Boost post (intégration dans la page existante)

> ⚠️ **La page boost post EXISTE DÉJÀ** : `lib/pages/user/userPubs/user_create_advertisement_page.dart`  
> Elle accepte un paramètre `existingPost` pour booster un post existant.  
> Elle gère déjà : sélection médias, durée en semaines, pays, type d'action, paiement.  
> Toute nouvelle fonctionnalité DOIT s'intégrer dans cette page existante.

**Modifications à apporter à `UserCreateAdvertisementPage`** :
1. Ajouter un toggle "Ajouter aussi mon profil / mon canal" avec prix dynamique (+50%)
2. Ajouter une section "Portée" visuelle (quartier → ville → pays → communautés)
3. Ajouter raccourcis vers "Booster mon profil" et "Booster mon canal" (si l'utilisateur n'a pas de post à booster)
4. Stocker les champs `ownerType`, `ownerId`, `ownerName`, `ownerAvatar` dans le document `Advertisements` créé

**Flux admin d'approbation (déjà existant, à compléter)** :
- Toute pub passe par une demande → statut `pending` → admin approuve → statut `active`
- À la soumission : envoyer notification **data + push** à l'admin (existant)
- ❌ **Notification email admin NON ENCORE FAITE** → à implémenter (Cloud Function `sendAdminAdEmail`)
  - Destinataire : officiel.afrolook@gmail.com
  - Contenu : nom créateur, type de boost, durée, montant, lien Firestore
- À l'approbation : notifier l'utilisateur (data + push) que sa pub est active
- À l'approbation : notifier l'utilisateur par email aussi (non fait)

**Fichiers à modifier** :
- [ ] `lib/pages/user/userPubs/user_create_advertisement_page.dart` → toggle combiné + champs owner
- [ ] `lib/models/model_data.dart` → ajouter `ownerType`, `ownerId`, `ownerName`, `ownerAvatar`, `ownerFollowers` à `Advertisement`
- [ ] Cloud Function `sendAdminAdEmail` (nouvelle) — email admin à la soumission
- [ ] Cloud Function `sendUserAdApprovedEmail` (nouvelle) — email utilisateur à l'approbation

---

### F7 — Midroll dans page vidéo paysage (`postDetailsVideo.dart`)

**Objectif** : Ajouter le système midroll (15s avant la fin) dans `VideoYoutubePageDetails` (page vidéo paysage), identique à celui de `post_video_format_tel_details.dart`.

**Différences avec la version portrait** :
- La page utilise `ChewieController` + `VideoPlayerController` (pas les mêmes que le feed)
- Le listener de position doit s'accrocher au `VideoPlayerController` directement
- Le modal midroll s'affiche par-dessus le player Chewie en plein écran

**Fichiers à modifier** :
- [ ] `lib/pages/postDetailsVideo.dart` → ajouter états midroll, timer, `_showMidrollOverlay()`, `_buildMidrollCard()`

---

## Ordre d'implémentation recommandé

| # | Tâche | Priorité | Statut |
|---|---|---|---|
| 1 | **F1** — Profil créateur dans les pubs existantes | 🔴 Haute | ⬜ À faire |
| 2 | **F7** — Midroll page vidéo paysage | 🔴 Haute | ⬜ À faire |
| 3 | **F6** — Page/modal boost post | 🟠 Moyenne | ⬜ À faire |
| 4 | **F2** — Boost profil utilisateur (modal + CF) | 🟠 Moyenne | ⬜ À faire |
| 5 | **F3** — Boost canal (modal + CF) | 🟠 Moyenne | ⬜ À faire |
| 6 | **F4** — Boost combiné post + profil/canal | 🟡 Standard | ⬜ À faire |
| 7 | **F5** — Affichage pubs profil/canal dans feed | 🟡 Standard | ⬜ À faire |

---

## Règles de sécurité à respecter

- Ne **jamais** afficher les 25% de commission Afrolook dans l'UI (afficher seulement le montant payé par le créateur)
- CinetPay Mobile Money **ne jamais** afficher dans le sélecteur de paiement
- Toujours passer par une **Cloud Function** pour les paiements (ne pas écrire directement en Firestore côté client)
- Les boosts doivent être validés `status: "active"` avant d'être affichés
- Ne **jamais** committer `functions/.env`

---

## Schéma de navigation boost

```
Post details / Menu options
  └── "Booster ce post" → PostBoostModal
        ├── Boost post seul → CF secureBoostPost
        └── Boost combiné (post + profil/canal) → CF secureBoostPost (crée 2 docs)

Page profil utilisateur
  └── "Booster mon profil" → ProfileBoostModal → CF secureProfileBoost

Page détails canal (propriétaire)
  └── "Booster ce canal" → CanalBoostModal → CF secureCanalBoost
```

---

## Questions ouvertes / décisions en attente

- [x] ~~Faut-il un système d'approbation admin pour les boosts profil/canal ?~~ → **OUI, même flux admin**
- [x] ~~Quel ciblage géographique ?~~ → **Même sélecteur de pays que `UserCreateAdvertisementPage`**
- [x] ~~Notifications groupées validées ?~~ → **OUI, style accordéon**
- [ ] Cap d'impressions quotidiennes par boost actif ?
- [ ] Les boosts profil/canal comptent-ils dans les stats créateur (dashboard) ?
- [ ] Y a-t-il une page "Mes boosts actifs" à créer ?
