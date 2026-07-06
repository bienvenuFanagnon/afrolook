# RESPONSIVE_DESKTOP_PLAN.md
> Référence de l'adaptation Desktop/Tablette — Afrolook V2  
> Mis à jour : 2026-07-06

---

## 1. Objectif général

Adapter l'interface Afrolook (aujourd'hui optimisée mobile) pour offrir une expérience confortable et moderne sur **Desktop (Web & app installée)** et **Tablette (Android & iPad)**, en s'inspirant de Facebook Web / LinkedIn Desktop.

Contraintes non-négociables :
- Une seule base de code Flutter
- Aucune régression mobile
- Aucune modification de la logique métier, des providers ni des services
- Limiter les changements aux fichiers de **layout** uniquement

---

## 2. Architecture responsive

### Breakpoints

| Nom       | Largeur          | Comportement principal                          |
|-----------|------------------|-------------------------------------------------|
| Mobile    | < 576 px         | Layout actuel inchangé                          |
| Tablet    | 576 – 992 px     | 2 colonnes (sidebar étroite 64px + feed centré) |
| Desktop   | > 992 px         | 3 colonnes (sidebar 220px + feed + panneau droit 300px) |

### Composants layout créés

| Fichier | Rôle | État |
|---------|------|------|
| `lib/layout/responsive_layout.dart` | `AppLayout` — helpers statiques (isWide, isDesktop…) | ✅ Créé |
| `lib/layout/centered_content.dart` | Conteneur centré max-width 680px | ✅ Créé |

### Hauteurs image/vidéo (mis à jour 2026-07-06)

| Élément | Avant | Après |
|---------|-------|-------|
| Images (1/2/3/4+) | `h * 0.40` | `h * 0.55` |
| Vignette vidéo locale | `h * 0.40` | `h * 0.55` |
| Hauteur vidéo YouTube | `screenWidth * 1.15`, clamp 320–500 | `screenWidth * 1.30`, clamp 380–620 |
| Thumbnail préchargement YouTube | `h * 0.25` | `h * 0.38` |

---

## 3. Liste complète des pages

### Phase 1 — Structure principale ✅ TERMINÉE

| Page | Fichier | État | Date | Résumé |
|------|---------|------|------|--------|
| Login | `lib/pages/auth/authTest/Screens/Login/loginPageUser.dart` | ✅ Fait | 2026-07-06 | 2 colonnes branding + formulaire |
| Création de compte | `lib/pages/auth/authTest/Screens/Signup/components/signup_form.dart` | ✅ Fait | 2026-07-06 | 2 colonnes branding + formulaire |
| HomeScreen | `lib/pages/home/homeScreen.dart` | ✅ Fait | 2026-07-06 | Sidebar + TopBar + panneau droit |
| Menu/Drawer | `lib/pages/home/homeScreen.dart` | ✅ Fait | 2026-07-06 | Sidebar intégrée dans _buildWideScaffold |
| Feed Looks/Events | `lib/pages/home/HomeConstPost.dart` | ✅ Fait | 2026-07-06 | Feed centré max 680px |
| Feed Sport | `lib/pages/home/homeSportPost.dart` | ✅ Fait | 2026-07-06 | Feed centré max 680px |

---

### Phase 2 — Parcours utilisateur principal

| Page | Fichier | État | Priorité |
|------|---------|------|----------|
| Profil utilisateur (mon profil) | `lib/pages/user/profile/profile.dart` | ✅ Fait | 🔴 Haute |
| Profil autre utilisateur | `lib/pages/user/otherUser/otherUser.dart` | ✅ Fait | 🔴 Haute |
| Détail post | `lib/pages/postDetails.dart` | ✅ Fait | 🔴 Haute |
| Détail post vidéo | `lib/pages/postDetailsVideo.dart` | ✅ Fait | 🔴 Haute |
| Commentaires | `lib/pages/postComments.dart` | ✅ Fait | 🔴 Haute |
| Liste conversations | `lib/pages/user/conversation/listUserConv.dart` | ✅ Fait | 🔴 Haute |
| Chat (conversation) | `lib/pages/chat/myChat.dart` | ✅ Fait | 🔴 Haute |
| Chat groupe | `lib/pages/chat/group/group_chat_page.dart` | ✅ Fait | 🟡 Moyenne |
| Chat entreprise | `lib/pages/chat/entrepriseChat.dart` | ✅ Fait | 🟡 Moyenne |
| Notifications | `lib/pages/mes_notifications.dart` | ✅ Fait | 🔴 Haute |
| Invitations | `lib/pages/user/amis/pageMesInvitations.dart` | ✅ Fait | 🔴 Haute |
| Mes amis | `lib/pages/user/amis/mesAmis.dart` | ✅ Fait | 🟡 Moyenne |
| Création de post | `lib/pages/userPosts/userPostForm.dart` | ✅ Fait | 🔴 Haute |

---

### Phase 3 — Contenu & divertissement

| Page | Fichier | État | Priorité |
|------|---------|------|----------|
| Feed vidéos (AfroVideos) | `lib/pages/socialVideos/afrovideos/afroFeedVideo.dart` | ✅ Fait | 🔴 Haute |
| Vibes (TikTok) | `lib/pages/vibe/vibesPage.dart` | ✅ Fait | 🔴 Haute |
| Post vidéo TikTok | `lib/pages/post_video_format_tel_details.dart` | ✅ Fait | 🔴 Haute |
| Lecteur vidéo | `lib/pages/socialVideos/videoPlayer.dart` | ⬜ À faire | 🟡 Moyenne |
| AfroVibes | `lib/pages/socialVideos/afrovibes/afroVibes.dart` | ⬜ À faire | 🟡 Moyenne |
| AfroLive (player) | `lib/pages/socialVideos/afrolive/afrolookLive.dart` | ⬜ À faire | 🟡 Moyenne |
| Liste des lives | `lib/pages/LiveAgora/live_list_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Créer un live | `lib/pages/LiveAgora/create_live_page.dart` | ⬜ À faire | 🟢 Basse |
| Live page | `lib/pages/LiveAgora/livePage.dart` | ⬜ À faire | 🟡 Moyenne |
| Classements | `lib/pages/classements/userClassement.dart` | ⬜ À faire | 🟡 Moyenne |
| Challenges (dashboard) | `lib/pages/challenge/challengeDashbord.dart` | ⬜ À faire | 🟡 Moyenne |
| Challenges (liste posts) | `lib/pages/challenge/listChallengePost.dart` | ⬜ À faire | 🟡 Moyenne |
| Chroniques (accueil) | `lib/pages/chronique/chroniquehome.dart` | ⬜ À faire | 🟡 Moyenne |
| Chronique (détail) | `lib/pages/chronique/chroniquedetails.dart` | ⬜ À faire | 🟡 Moyenne |
| Feed unifié | `lib/pages/feed/unified_feed_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Pronostics (feed) | `lib/pages/pronostics/pronostics_feed_page.dart` | ⬜ À faire | 🟢 Basse |
| Pronostic (détail) | `lib/pages/pronostics/pronostic_detail_page.dart` | ⬜ À faire | 🟢 Basse |
| Posts favoris | `lib/pages/userPosts/favorites_posts.dart` | ⬜ À faire | 🟢 Basse |

---

### Phase 4 — Dating / Afrolove

| Page | Fichier | État | Priorité |
|------|---------|------|----------|
| Entrée Dating | `lib/pages/dating/dating_entry_page.dart` | ⬜ À faire | 🔴 Haute |
| Explorer (swipe) | `lib/pages/dating/dating_explore_page.dart` | ⬜ À faire | 🔴 Haute |
| Profil Dating | `lib/pages/dating/dating_profile_detail_page.dart` | ⬜ À faire | 🔴 Haute |
| Connexions | `lib/pages/dating/dating_connections_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Conversations Dating | `lib/pages/dating/dating_conversations_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Chat Dating | `lib/pages/dating/dating_chat_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Notifications Dating | `lib/pages/dating/dating_notifications_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Profil Créateur | `lib/pages/dating/creator_profile_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Liste profils | `lib/pages/dating/dating_profiles_list_page.dart` | ⬜ À faire | 🟢 Basse |
| Carte (map) | `lib/pages/dating/dating_map_page.dart` | ⬜ À faire | 🟢 Basse |

---

### Phase 5 — Business & Monétisation

| Page | Fichier | État | Priorité |
|------|---------|------|----------|
| Dashboard Contenu Payant | `lib/pages/contenuPayant/TableauDeBord.dart` | ✅ Fait | 🔴 Haute |
| Détail contenu | `lib/pages/contenuPayant/content_detail_page.dart` | ⬜ À faire | 🔴 Haute |
| Mes achats | `lib/pages/contenuPayant/my_purchases_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Marketplace affiliation | `lib/pages/contenuPayant/affiliation_marketplace_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Rémunération | `lib/pages/user/remuneration_home_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Monétisation | `lib/pages/user/monetisation.dart` | ⬜ À faire | 🟡 Moyenne |
| Transactions | `lib/pages/user/userTransactionListe.dart` | ⬜ À faire | 🟢 Basse |
| Dépôt/Paiement | `lib/pages/paiement/depotPaiment.dart` | ⬜ À faire | 🟢 Basse |
| Pubs (mes annonces) | `lib/pages/user/userPubs/user_my_advertisements_page.dart` | ⬜ À faire | 🟢 Basse |
| Créer annonce | `lib/pages/user/userPubs/user_create_advertisement_page.dart` | ⬜ À faire | 🟢 Basse |

---

### Phase 6 — Afroshop

| Page | Fichier | État | Priorité |
|------|---------|------|----------|
| Accueil Afroshop | `lib/pages/afroshop/marketPlace/acceuil/home_afroshop.dart` | ⬜ À faire | 🔴 Haute |
| Détail produit | `lib/pages/afroshop/marketPlace/acceuil/produit_details.dart` | ⬜ À faire | 🟡 Moyenne |
| Ajouter produit | `lib/pages/afroshop/marketPlace/new/addProduit.dart` | ⬜ À faire | 🟢 Basse |
| Créer boutique | `lib/pages/afroshop/marketPlace/new/add_store.dart` | ⬜ À faire | 🟢 Basse |

---

### Phase 7 — Canaux & Communautés

| Page | Fichier | État | Priorité |
|------|---------|------|----------|
| Liste canaux | `lib/pages/canaux/listCanal.dart` | ⬜ À faire | 🟡 Moyenne |
| Détail canal | `lib/pages/canaux/detailsCanal.dart` | ⬜ À faire | 🟡 Moyenne |
| Nouveau post canal | `lib/pages/canaux/canalPostNew.dart` | ⬜ À faire | 🟢 Basse |
| Créer canal | `lib/pages/canaux/newCanal.dart` | ⬜ À faire | 🟢 Basse |

---

### Phase 8 — Profil entreprise & Services

| Page | Fichier | État | Priorité |
|------|---------|------|----------|
| Profil entreprise | `lib/pages/entreprise/profile/ProfileEntreprise.dart` | ⬜ À faire | 🟡 Moyenne |
| Services utilisateur | `lib/pages/UserServices/listUserService.dart` | ⬜ À faire | 🟢 Basse |
| Détail service | `lib/pages/UserServices/detailsUserService.dart` | ⬜ À faire | 🟢 Basse |

---

### Phase Admin — Pages d'administration

| Page | Fichier | État | Priorité |
|------|---------|------|----------|
| Dashboard admin | `lib/pages/admin/admin_dashboard_page.dart` | ⬜ À faire | 🔴 Haute |
| Pub admin | `lib/pages/admin/ad_admin_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Ajout info app | `lib/pages/admin/addAppInfo.dart` | ⬜ À faire | 🟡 Moyenne |
| Ajout info gratuit | `lib/pages/admin/addGratuitInfo.dart` | ⬜ À faire | 🟡 Moyenne |
| Email admin | `lib/pages/admin/admin_email_screen.dart` | ⬜ À faire | 🟡 Moyenne |
| Annonces | `lib/pages/admin/annonce.dart` | ⬜ À faire | 🟡 Moyenne |
| Demandes influenceurs | `lib/pages/admin/influencer_requests_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Nouvelle catégorie | `lib/pages/admin/new_category.dart` | ⬜ À faire | 🟢 Basse |
| Comptes officiels | `lib/pages/admin/official_accounts_page.dart` | ⬜ À faire | 🟡 Moyenne |
| Rémunération admin | `lib/pages/admin/remuneration_admin_page.dart` | ⬜ À faire | 🟡 Moyenne |

---

### Non prioritaire / hors scope

Ces pages sont principalement des formulaires courts, modales :

- Marketing (`lib/pages/Marketing/`)
- Introduction / Splash (`lib/pages/intro/`, `lib/pages/splashVideo.dart`)
- Formulaires courts (newChallenge, newCanal, updateUserData…)
- Modales (bottomSheet, dialog…)
- Pages technique (feed_cache_service, video_preload_manager…)

---

## 4. Checklist par phase

### Phase 1 — Structure principale
- [x] Créer `lib/layout/responsive_layout.dart`
- [x] Créer `lib/layout/centered_content.dart`
- [x] **Login** — 2 colonnes desktop
- [x] **Création de compte** — 2 colonnes desktop
- [x] **HomeScreen** — Sidebar + TopBar + panneau droit
- [x] **HomeConstPost** — Feed centré
- [x] **HomeSportPage** — Feed centré
- [x] **Hauteurs image/vidéo** — `h*0.40` → `h*0.55`, vidéo clamp 380–620

### Phase 2 — Parcours utilisateur principal
- [x] Profil utilisateur
- [x] Profil autre utilisateur
- [x] Détail post / Commentaires
- [x] Conversations + Chat (WhatsApp layout, 2-colonnes desktop)
- [x] Chat groupe / Chat entreprise
- [x] Notifications
- [x] Invitations
- [x] Mes amis
- [x] Création de post
- [x] Détail post vidéo

### Phase 3 — Contenu & divertissement
- [x] Feed vidéos AfroVideos + clavier ↑↓ + scroll souris
- [x] Vibes (TikTok) + clavier ↑↓ + scroll souris
- [x] Post vidéo TikTok + clavier ↑↓ + scroll souris
- [ ] Lives (list + player)
- [ ] Challenges
- [ ] Chroniques
- [ ] Classements
- [ ] Feed unifié

### Phase 4 — Dating
- [ ] Dating entry + swipe
- [ ] Profils + connexions
- [ ] Chat dating
- [ ] Créateur dating

### Phase 5 — Business & Monétisation
- [x] Dashboard contenu payant (TableauDeBord)
- [ ] Détail contenu + achats
- [ ] Rémunération + monétisation

### Phase 6 — Afroshop
- [ ] Accueil + détail produit

### Phase 7 — Canaux
- [ ] Liste + détail canaux

### Vérification globale (à faire après chaque phase)
- [ ] Aucune régression mobile (375px)
- [ ] Tablette 768px correct
- [ ] Desktop 1280px correct
- [ ] Dark mode fonctionnel
- [ ] flutter analyze sans nouvelles erreurs

---

## 5. Journal des décisions

| Date | Décision | Fichiers impactés | Raison |
|------|----------|-------------------|--------|
| 2026-07-06 | Partager tablet et desktop sur un seul layout "wide" (≥576px) | `responsive_layout.dart` | Simplification — UX identique sur les deux |
| 2026-07-06 | Conserver `Responsive` existant | `responsive.dart` | Éviter la casse des pages déjà adaptées |
| 2026-07-06 | Max-width 680px pour le feed | `centered_content.dart` | Lisibilité — au-delà de 680px les posts sont trop larges |
| 2026-07-06 | NavigationRail avec labels sur desktop, icônes seules sur tablette | `homeScreen.dart` | Largeur 220px insuffisante pour texte sur tablette |
| 2026-07-06 | Panneau droit (300px) uniquement sur desktop (>992px) | `homeScreen.dart` | Tablette : pas assez de place pour 3 colonnes |
| 2026-07-06 | Hauteurs image/vidéo augmentées : `h*0.4` → `h*0.55` | `postWidgetPage.dart`, `youTube_video_card.dart` | Affichage trop petit sur desktop/tablette |
| 2026-07-06 | Vidéo YouTube : clamp max 500→620, ratio 1.15→1.30 | `youTube_video_card.dart` | Meilleure utilisation de l'espace sur grand écran |
| 2026-07-06 | Pages TikTok centrées à 480px + KeyboardListener + Listener scroll | `afroFeedVideo.dart`, `vibesPage.dart`, `post_video_format_tel_details.dart` | Navigation clavier ↑↓ et molette souris sur desktop/web |
| 2026-07-06 | Chat WhatsApp 2-colonnes (360px liste + expanded) sur wide | `listUserConv.dart` | UX desktop : conversation active visible sans changer de page |
| 2026-07-06 | Sections desktop inline dans HomeScreen (sidebar + panneau droit) | `homeScreen.dart` | Évite la navigation pleine page pour Messages, Business, Lives, etc. |

---

*Ce fichier est mis à jour à chaque étape du développement.*
