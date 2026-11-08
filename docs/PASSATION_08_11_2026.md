# Passation du 08/11/2026 (pour l'agent suivant)

À lire avec `docs/PROJET_MEMOIRE.md` (mémoire unique du projet) et `CLAUDE.md`. Cette note résume ce qui a été fait du 07 au 08/11/2026, ce qui reste, comment vérifier, et les pièges.

## 1. État des dépôts

| Dépôt | Dossier | Branches | État |
|---|---|---|---|
| API Laravel | `V2/afrolook-api` | `develop` = `main` = GitHub (`7569149`) | à jour ; **dernier déploiement fait = `225b7b4`** : il manque encore un `deploy.sh` (classement paginé) |
| Application Flutter | `V2/afrolookofficiel_v2` | `main` (déploiement) | version **2.1.2+275** ; le propriétaire pousse lui-même (`git push origin main`) |
| Site | `V2/site_api_test` | — | non touché cette session (voir §6) |

Règles constantes : ne jamais pousser sans demande (le propriétaire pousse), ne rien changer à la production sans l'accord du propriétaire, aucun secret dans le dépôt, **proposer avant d'agir** pour tout changement visuel important (maquette HTML dans `docs/maquettes/`), répondre en français avec accents, textes de l'application via `context.tr(...)` avec les 7 autres langues dans `lib/l10n/tr_videos.dart`, vocabulaire « Afrolook Ads » (jamais la part gardée, jamais l'application dans les pages de la régie), jaune seulement en fond (texte noir dessus), thème clair + sombre.

Deux commits « correction release » (`24730bab`, `5051450f`) viennent du propriétaire (`authProvider.dart`, `pubspec`). `pubspec.lock` est modifié localement chez lui : ne pas y toucher.

## 2. Déploiement

**API** (sur le VPS, utilisateur `deploy`) :
```bash
sudo -u deploy bash -c 'cd /var/www/afrolook-api && bash ./deploy/deploy.sh main'
sudo -u deploy bash -c 'cd /var/www/afrolook-staging && APP_DIR=/var/www/afrolook-staging APP_HOST=api-staging.afrolookmedia.com bash ./deploy/deploy.sh main'
```
Migrations de la période (le script les passe seul) : `2026_11_07_001800_widen_reference_ids`, `…001900_post_widgets`, `…002000_widgets_on_chronicles`, `2026_11_08_000100_widget_reminders_notified`, `2026_11_08_000200_points`. **Déjà passées** sur le test et la production (points : `points:rebuild` lancé des deux côtés le 08/11 : test 2067 comptes / 62 624 points, production 2112 / 63 778).

Commandes planifiées ajoutées : `widgets:remind` (chaque minute), `staff:expire` (chaque heure). Commandes manuelles : `points:rebuild`, `staff:bootstrap`.

**Application** : Android = release complète (pas un patch Shorebird : changements natifs) ; iOS = Codemagic. Codemagic a échoué deux fois sur `UnityAds.zip` (GitHub 504/503) : `pod install` réessaie maintenant 5 fois (`codemagic.yaml`). Les messages « Found multiple specifications » sont de simples avertissements.

## 3. Ce qui est fait (par domaine)

**Téléchargement / signature** : signature sobre (3 emplacements, QR sur la carte de fin), fin Afrolook toujours ajoutée, cache partagé (`/posts/{id}/signed-download`), cause du « serveur rencontre un problème » = ids trop longs (`post_downloads`), migration 001800.

**Gratuité** : tout le Studio gratuit jusqu'au 31/12/2026 (interrupteurs `REWARDS_ALL_FREE`, `REWARDS_FREE_UNTIL`) ; retrait de la fin Afrolook et « Galerie illimitée avec Gold » restent Gold (décision du propriétaire).

**Répondre en vidéo** : bandeau `ReplyBanner`, boutons « Répondre » partout, aperçu en direct (`lib/widgets/reply_split.dart`). Push `VIDEO_REPLY` en catégorie **directe** (hors budget) avec `post_id` ; la notification s'ouvre depuis la liste (`notification_text.dart`, `mes_notifications.dart`).

**Widgets** (11 types, 3 au plus, jamais Gold) : API `app/Posts/Widgets.php`, `PostWidgetController`, table `post_widgets` (`post_id` ou `chronicle_id`) ; app `lib/models/post_widget.dart`, `lib/widgets/post_widget_view.dart` (`PostWidgetsLayer` avec `mediaAspect` et `video` pour la plage « de… à… »), `lib/widgets/widgets_sheet.dart`. Éditeur : déplacer, pincer, supprimer, plage, « Annuler », confirmation de retour + brouillon (`lib/services/create_draft.dart`). Auteur : `is_author` + « Voir les réponses ». Rappels poussés : `widgets:remind`.

**Éditeur / formats** : média affiché dans son **format réel** (éditeur, chroniques) ; positions des widgets comptées dans le cadre du média (`mediaFrame`, `widgetAlignment`).

**Montage à deux médias** (`app/Studio/Montage.php`, `StudioMontageController`, `lib/pages/studio/montage/*`) : dispositions `tb`/`sbs`/`bar`/coin, collées (`LAYOUT_GAP = 0`), part 25–75 %, zoom 1–2,5 par média, inverser, son d'origine réglable (coin et dispositions, calé sur le créneau), mini-vidéo jusqu'à toute la largeur et à son format réel, lecture sans boucle, **vidéo OU image de la galerie** en 2e média (`pins.*.upload_id`, vérification d'authenticité), aperçu en direct. Réglages du Studio rangés en sections repliables.

**Montage de plusieurs images** (maquette validée) : `lib/pages/create/multi_images_page.dart` (carrousel / collage / diaporama, 2 à 5 images), `lib/services/collage_layouts.dart` (mises en page + rendu PNG 4:5), API `app/Studio/Slideshow.php` + `StudioSlideshowController` (`POST /studio/slideshow`, xfade ffmpeg). L'envoi des images lit le **vrai type** dans les octets (`ArgentUpload.sniffImageType`), car le serveur refuse un type d'extension faux.

**Équipe** : API déjà présente (types, droits, quatre yeux, journal) ; ajouts : pseudos, `GET /admin/staff/catalog` et `/lookup`, stagiaire 90 jours au plus, `staff:expire`. App : `lib/pages/admin/team_admin_page.dart` (l'ancien espace réservé « mise de côté » est supprimé), accès par le profil pour tout compte qui a `staff.manage`. Super-administrateurs créés par le propriétaire (`staff:bootstrap`).

**Points et classement** (`app/Accounts/Points.php`, `Popularity.php`, `config/points.php`, `users.points`, `app_stats.points_total`, `point_log` unique par personne/type/cible) : inscription 5, parrain 5, aimer 1 (jamais sur sa publication), s'abonner 4, inviter 1 ; popularité = points du compte / points de l'application x 100. Top Afrolook Stars (`lib/pages/classements/userClassement.dart`) : API `GET /users/top?by=points&limit&offset` jusqu'au rang 500, clair/sombre, « Mes points ». Au menu : Récompenses et Top stars en haut. Règle inconnue : les anciennes fonctions serveur qui calculaient `totalPoints` n'ont pas été retrouvées (valeurs reprises du code lisible de l'ancienne app).

**Modal de profil** : proposition A (verre) choisie ; chiffres lus sur le serveur (`popularity`, `referrals_count`, `is_friend`, `invitation_sent`) ; bouton « Message » pour les amis.

**Pubs** : le stock envoie `views`/`clicks` ; une vue valide d'un boost compte aussi comme vue de la publication ; pages plein écran sans page noire (`lib/ads/fullscreen_ad_page.dart`) : pub du réseau préchargée (signal `onLoaded`), décompte 5 s, repli Afrolook Ads (3 s image / 5 s vidéo), saut automatique s'il n'y a rien ; branché dans le lecteur vertical et les chroniques.

**Divers** : détail d'un post dit maintenant `liked_by_me` ; compte sans pseudo n'affiche plus « @ » ; bouton **texte** « Suivre » / « S'abonner » sur la ligne du pseudo du lecteur vertical.

## 4. À vérifier sur téléphone (jamais vu à l'écran)

Aperçu à deux vidéos dans la caméra (moteur de filtres de visage) ; pubs réelles (AdMob/Appodeal) et décomptes ; diaporama de bout en bout ; bouton Suivre sur petits écrans (la place du badge « Authentique ») ; Top stars avec de vrais points ; modal de profil A.

## 5. Décisions en attente / propositions à valider

- **Site, onglet Partageurs** : maquette `docs/maquettes/site_partageurs_proposition.html` (petite grille + détail au clic + gains « gagné / en attente / clics »), à valider ; question : montants en pièces, en FCFA, ou les deux.
- **Texte coloré** (écran « Texte » de Créer) : aujourd'hui le texte est rendu en **image** (couleur dans l'image) ; une vraie carte colorée dans chaque écran demande un style enregistré côté serveur et un dessin dans le fil, les détails et les chroniques : proposition visuelle à faire si le propriétaire le veut.
- Autres ancres : autres envois d'images (boutique, services, profil admin) lisent encore le type par l'extension ; version Apple 34 (adaptateurs allégés) pour la prochaine mise à jour.

## 6. Site (`V2/site_api_test`)

Source `src/*.mjs`, scripts `static/js/*.js`, CSS `static/css/*.css`, sortie `dist/` (construite par `build.mjs`). L'onglet Partageurs est dans `static/js/ads.js` (`sharerCard`, onglets ligne ~768, chargement ligne ~903 via `adsPubAdminList({ sharers: true })`) ; le style des cartes `.rg-card` est dans `static/css/ads.css` (lignes ~235 et ~391). Données côté API : `app/Ads/Space/SpaceAdmin.php::sharers()`. Les gains viennent de `share_earnings` (`status` : `held`/`blocked` = en attente, `released` = versé, `cancelled` ignoré ; `hundredths` = centièmes de pièce, `coins_paid` = pièces versées) et les clics de `share_links.valid_total`.

## 7. Pièges techniques rencontrés

- **Windows / Git Bash** : les heredocs avec antislash cassent le Python et le PHP : écrire les scripts avec l'outil d'écriture de fichiers, jamais en ligne. Beaucoup de fichiers Dart sont en CRLF : lire en `newline=''` et réécrire à l'identique. `chroniquedetails.dart` commence par un BOM : ne pas insérer de ligne avant lui sans le retirer.
- **Tests** : l'API (`php artisan test`) dure ~8 minutes ; Flutter `flutter test <fichiers>` ciblés (la suite entière dépasse 10 minutes). Les tests ffmpeg sont réels (ils se sautent seuls si ffmpeg manque).
- **Production** : ne pas lire ses journaux soi-même ; donner les commandes au propriétaire.
- **Sorties de scripts** : toujours vérifier qu'un patch s'est bien appliqué (un motif introuvable arrête le script sans rien écrire).

## 8. Reste à faire (ordre proposé)

1. ~~Refonte de l'onglet Partageurs~~ **faite le 08/11** (maquette validée) : API `SpaceAdmin::sharers()` + `totals` (commit `b0935c4`, à déployer) ; site `static/js/ads.js` (`sharersView`, `sharerMini`, `sharerSheet`), `ads.css` (`.sh-*`), `ASSET_V = 24`, `dist/` reconstruit. Reste : `firebase deploy --only hosting` par le propriétaire et vérification à l'écran (jamais vu avec de vraies données).
2. Retours du propriétaire après l'essai sur téléphone (voir §4).
3. Éventuelle carte-texte colorée vivante (§5) et montage multi-images : retouche par image ajoutée au diaporama, si demandée.
4. Gestion de l'équipe : tout est fait côté code ; reste l'usage réel (créer des membres depuis l'écran Équipe).
