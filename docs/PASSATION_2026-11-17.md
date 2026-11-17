# Passation — travail du vendredi 13 au mardi 17 novembre 2026

> À donner tel quel à l'agent qui reprend. Tout est en français ; le propriétaire parle français et attend des réponses simples, directes, avec les accents.

---

## Prompt à donner à l'agent

Tu reprends le travail sur **Afrolook** (réseau social + régie publicitaire « Afrolook Ads »). Avant toute action :

1. Lis `CLAUDE.md` (racine de `afrolookofficiel_v2`), puis **`docs/PROJET_MEMOIRE.md`** (mémoire unique du projet). Le journal du 13 au 17/11 est vers les lignes **308 à 352** (16–17/11, plus récent en haut) et **700 à 710** (13/11).
2. Lis **ce fichier en entier** : il dit ce qui est fait, ce qui n'est pas committé, pas déployé, et ce qui reste.
3. Avant de toucher aux règles, paiements, comptes ou administrateurs : `docs/SECURITE_API.md`. Organisation : `docs/AGENTS_ET_ORGANISATION.md`.
4. La mémoire automatique de Claude Code (si tu y as accès) est dans `C:\Users\ANVT\.claude\projects\D--bienvenu-Projets-otherProjets-afrolook-V2-afrolookofficiel-v2\memory\` (index `MEMORY.md`).

**Règles du propriétaire (à respecter strictement)**
- Réponds en **français** correct ; **pose les questions avant d'agir** quand un choix existe ; **propose avant tout changement important**.
- **Ne committe pas, ne pousse pas, ne déploie pas sans demande explicite** (« à ma demande tu déploies »). **Jamais de build AAB/APK/IPA ni de patch Shorebird de ta propre initiative.**
- Version de l'application à **deux endroits** : `pubspec.yaml` ET `lib/providers/authProvider.dart` (`app_version_code`), même numéro de build.
- **Aucun emoji** dans l'interface : icônes dédiées (`Icons.*`).
- Pages de la régie : dire **« Afrolook Ads »**, ne **jamais** afficher la part gardée par Afrolook (ni les 25 % de l'app, ni le complément des 65 % des diffuseurs).
- Plans : **Gratuit ou Gold** seulement. Les **spectateurs ne paient jamais** dans les lives.
- Aucun secret dans le dépôt ni dans les messages. Ne cherche pas de fichiers de clés sur le disque.
- En fin de session : une ligne dans le journal de `docs/PROJET_MEMOIRE.md`.

---

## Dépôts, outils et commandes

| Élément | Chemin / valeur |
|---|---|
| Application Flutter + site | `D:\bienvenu\Projets\otherProjets\afrolook\V2\afrolookofficiel_v2` (le site est dans `site/`) |
| API Laravel | `D:\bienvenu\Projets\otherProjets\afrolook\V2\afrolook-api` |
| Serveur (VPS) | `root@185.170.12.250`, clé `C:/Users/ANVT/.ssh/afrolook_vps` ; test : `/var/www/afrolook-staging` (https://api-staging.afrolookmedia.com) ; production : `/var/www/afrolook-api` |

- **Tests API** (Git Bash) : `export OPENSSL_CONF='C:\xampp\apache\conf\openssl.cnf'` puis `php vendor/bin/pest …`. Suite complète ≈ 1 620 tests, ~13 min, **sans `--parallel`** (le mode parallèle échoue : droits Postgres). Des échecs isolés « table inexistante » viennent de la base de test : relancer le fichier seul.
- **Tests application** : `flutter test test/<fichier>` ; `test/feed_sound_card_test.dart` échoue déjà (Firebase non initialisé dans le test), sans lien avec le travail récent.
- **Pièges Git Bash** : `/app/` et `/v1/...` sont transformés en chemins Windows → lancer `flutter build web` dans **PowerShell** ; pour les scripts ASC, `MSYS_NO_PATHCONV=1`. Les fichiers sont souvent en CRLF.
- **Site** (vitrine + /ads/ + /app/ se déploient **toujours ensemble**) — PowerShell, depuis `afrolookofficiel_v2` :
  1. `flutter build web --release --base-href "/app/" --no-tree-shake-icons --no-wasm-dry-run --no-web-resources-cdn`
  2. `cd site; node build.mjs; node check.mjs` (doit afficher « OK : 154 pages »)
  3. `firebase deploy --only hosting:vitrine --project afrolooki`
  - Aperçu local : configuration `refonte-site-dist` (sert `site/dist` sur le port 5197). L'espace annonceur exige Google : pour tester, afficher le formulaire dans la console (`#adgate` caché, `#adapp` et `#tab-creer` visibles).
- **API** : test d'abord — `ssh … "bash /var/www/afrolook-staging/deploy/deploy-test.sh main"` ; production (le propriétaire tape `PRODUCTION`) : `cd /var/www/afrolook-api && sudo bash deploy/deploy-prod.sh` (sauvegarde, migrations, retour arrière si `/up` échoue). Pousser l'API : `git push origin main main:develop` puis `git branch -f develop main`.
- **Pousser l'application** : `git push origin main main:branche_api main:filtres-moteur`. Messages de commit terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Shorebird** : Android release **2.1.8+285** (l'AAB envoyé au store doit être celui produit par `shorebird release`) ; iPhone release **2.1.8+42** (workflows Codemagic `ios-shorebird-release` et `ios-shorebird-patch` avec `RELEASE_VERSION`). Le propriétaire a lancé `shorebird patch android --release-version 2.1.8+285` le 16/11 (canal choisi non confirmé).

---

## Ce qui a été fait (résumé par jour — détails dans le journal)

**Vendredi 13/11** — authenticité et modération des posts ; **lives à plusieurs + minutes Agora** (règle absolue : Afrolook ne paie jamais Agora au-delà des 10 000 minutes gratuites ; billets de 15 min) ; écran du live (billet) ; « six idées » des lives codées.

**Samedi 14/11** — écran noir des lives corrigé ; **live sans caméra** ; j'aime, cadeaux, quiz, musique, épingles ; duel, scène à plusieurs, meilleurs donateurs ; commandes du live, alertes, codes promo ; **annulation des commandes** (sans pénalité, seulement avant validation du vendeur) ; alerte « vendeur dans un autre pays » ; version **2.1.6 (282)** envoyée aux boutiques.

**Dimanche 15/11** — vues uniques dans les interactions ; 2.1.6 en revue Apple ; quiz jusqu'à 30 min par question ; bug « Mes commandes » ; patch Shorebird refusé (hash) → **2.1.7+283** ; **refonte du quiz** (compact dans le live, questions Afrolook, classement des 20 premiers, sans cagnotte par défaut) ; **plus de Premium (Gratuit ou Gold)** ; **les spectateurs ne paient plus** (l'hôte paie 50 + 50/spectateur par quart d'heure, sinon vidéo coupée).

**Lundi 16/11**
- Version **2.1.8+285** ; **Tapjoy retiré** ; **Shorebird iPhone** dans Codemagic ; plantage caméra Android corrigé ; notification « nouveau post » ouvre le post ; **2.1.8 (build 42) envoyée en revue Apple**.
- **Quiz** : modes clair/sombre, **séries de questions enregistrées** (Gold, 20 séries × 50), questions Afrolook dès la création, **historique des jeux avec classements** (live terminé et Mes lives), réponses longues sur 2 lignes, emojis remplacés par des icônes.
- **Annonces d'application à deux liens** (Google Play + App Store, bon lien selon l'appareil, page à deux boutons sur ordinateur, logo de la boutique sur « Installer »).
- **Notifications** : au moins 5, au plus 15 par jour (rappels 9 h, 12 h, 15 h, 18 h, 20 h 30), relance après 24 h, tout dans la liste, publications regroupées, aperçu (type, description, image).
- **Page /ads** : visites estimées 20–60 % (décision du propriétaire malgré deux avertissements), maquettes des formats.
- **Affichage des annonces** : image entière sur fond flouté (application + tag des sites partenaires `site/static/ads/tag.js`), en-tête de marque, bannières prêtes à la taille de l'emplacement, **GIF accepté** comme petite vidéo, **vidéo sur la page d'atterrissage** des campagnes de partage.
- **Formulaire /ads/ (espace annonceur)** : **aperçus en direct** dès l'ouverture (Dans Afrolook / Sites partenaires téléphone + ordinateur rendus par le vrai `tag.js` en mode aperçu / Partage), clic sur l'image d'un aperçu pour la remplacer, contrôle immédiat (< 400 px refusé), « Voir en grand » ; **bannières prêtes toujours visibles** avec badge « Plus de vues et de clics » et compteur « X formats sur 4 » ; **galerie d'exemples d'annonces réussies** ; **bannières créées automatiquement** dans le navigateur dès que l'image est choisie (comptent comme bannières prêtes, couleur tirée de l'image, remplaçables) ; message « image principale » dans les aperçus ; boutons **Image / GIF animé / Vidéo**.
- **Son des vidéos** : la carte du fil coupait le son de toute l'app → corrigé, **son activé dans le fil et la page portrait** ; nouvelle clé `global_sound_muted_v2`. **Boutons de volume** du téléphone réactivent le son (`volume_controller` 3.7.1, ajouté par le propriétaire) → **version 2.1.9+286** (module natif : nouvelle version store, pas de patch).
- **Montage** : texte jusqu'à **250 caractères** (police réduite au-delà de 120).

**Mardi 17/11**
- **Tout repose sur le budget** (décision) : plus de durée pour une annonce payante (Afrolook / partenaires) ; l'annonce tourne jusqu'à épuisement ; champ « Durée » remplacé par une note ; annonces payantes en cours sans date de fin (migration `2026_11_17_000100_ads_budget_only`). L'annonce gratuite garde 14 jours, la partie « partage seul » sa durée.
- **Bannières automatiques pour les annonces existantes** (en ligne et en validation) : `app/Ads/AutoBanners.php` (GD, police DejaVu sur le serveur) + commande **`php artisan ads:auto-banners`** (`--dry-run`, `--id=`), tailles manquantes seulement, notées dans `banners.auto`.
- Kit d'annonce **PronoFlash IA** préparé.

---

## État actuel — RIEN de ce qui suit n'est committé ni déployé

**Application / site (`afrolookofficiel_v2`)** — dernier commit poussé : `da183581`.
Non committé : aperçus + exemples + bannières auto + boutons Image/GIF/Vidéo + note « budget » (`site/src/ads.mjs`, `site/static/js/ads.js`, `site/static/css/ads.css`, `site/static/ads/tag.js`, nouveau dossier `site/static/img/ads/exemples/`) ; son des vidéos et boutons de volume (`lib/providers/sound_provider.dart`, `lib/pages/userPosts/youTube_video_card.dart`, `pubspec.yaml`/`pubspec.lock` avec `volume_controller`, fichiers de plugins générés linux/macos) ; montage 250 caractères (`lib/pages/studio/montage/montage_editor_page.dart`, `montage_text_style.dart`) ; version **2.1.9+286** (`pubspec.yaml`, `authProvider.dart`) ; tests (`test/sound_provider_test.dart`, `test/montage_text_style_test.dart`) ; journal.

**API (`afrolook-api`)** — dernier commit poussé et **déployé en production** : `109ecf8`.
Non committé : `app/Ads/Space/Advertisers.php` (budget seul), `app/Ads/AutoBanners.php`, `app/Console/Commands/AdsAutoBanners.php`, `database/migrations/2026_11_17_000100_ads_budget_only.php`, `tests/Feature/AutoBannersTest.php`, `tests/Feature/AdEnvelopesTest.php`.
Une suite complète des tests de l'API a été lancée le 17/11 ; résultat dans `C:\Users\ANVT\AppData\Local\Temp\claude\6cdc3ff42271f611\bed14e79-b06c-42c4-bfb1-f83031df0fda\scratchpad\suite_api3.txt` (si le dossier temporaire existe encore ; sinon relancer). Tests ciblés déjà verts : AutoBannersTest (4), AdEnvelopesTest, SiteSpaceTest, AdsPoolTest, AdsTest (64).

**Site en ligne** : version du 16/11 (sans les aperçus récents) — le propriétaire déploie lui-même ou demande.

---

## Ce qui reste à faire (dans cet ordre, en demandant l'accord du propriétaire)

1. Vérifier la suite complète de l'API, puis **committer et pousser** les deux dépôts quand le propriétaire le demande.
2. **API** : serveur de test (`deploy-test.sh`, la migration « budget seul » s'applique) → essai `php artisan ads:auto-banners --dry-run` puis réel sur le test → production (le propriétaire tape `PRODUCTION`) → `ads:auto-banners --dry-run` puis réel en production.
3. **Site** : `node build.mjs`, `node check.mjs`, `firebase deploy …` (après l'API).
4. **Release 2.1.9+286** (son + boutons de volume + 250 caractères) : nouvelle version store via `shorebird release` (Android) et Codemagic `ios-shorebird-release` — **seulement sur demande**.
5. **Kit d'annonce SlashAtlas** à préparer (même méthode que PronoFlash : visiter le site, logo/couleurs, photos Pexels, fiche, zip classé par case).

**Questions ouvertes à poser au propriétaire**
- **Catégorie de l'annonce PronoFlash IA** : « Sport et loisirs » ou « Paris sportifs et jeux d'argent » (le site fait des coupons, a une page Jeu responsable, mais ne prend aucun pari).
- **Vidéo + images dans une même annonce** (vidéo pour les emplacements vidéo, images pour les cartes) : non fait, demande une évolution de l'API (`Clean::adInput`, une seule vidéo OU 1–5 images aujourd'hui).
- Aperçus visibles aussi dans « Mes annonces » après l'envoi : sans préférence, non fait.
- Ordre des commentaires signalé : où l'a-t-il vu ? (dans le code, la page des commentaires d'un post affiche le plus récent en premier).
- Règle « rien sur l'application dans les pages de la régie » : la galerie d'exemples montre une pub de l'application Afrolook, ajoutée à sa demande explicite — à confirmer s'il veut d'autres exemples.

---

## Fichiers des annonces (images, fiches, outils)

| Contenu | Chemin |
|---|---|
| Pub de l'**application Afrolook**, tous formats (18 fichiers) + zip classé par case du formulaire + fiche (titre, texte, liens stores, réglages) | `afrolookofficiel_v2\images_test_annonces\` — `images_test_annonces_afrolook.zip`, `FICHE_ANNONCE.txt`, `LISEZ-MOI` dans le zip |
| Pub **PronoFlash IA** (https://pronoflashia.web.app/) tous formats + zip + fiche + logo | `afrolookofficiel_v2\images_annonce_pronoflash\` — `annonce_pronoflash.zip`, `FICHE_ANNONCE.txt`, `logo_pronoflash_180.png` |
| Exemples montrés dans le formulaire /ads/ (versions allégées) | `afrolookofficiel_v2\site\static\img\ads\exemples\` |
| Scripts de génération (ffmpeg) et rendu serveur | `afrolookofficiel_v2\images_test_annonces\outils\` — `gen_pubs.py` (Afrolook), `gen_prono.py` (PronoFlash), `ab_render.php` (essai visuel d'`AutoBanners`) ; **les chemins dans les scripts pointent vers l'ancien dossier temporaire : les adapter** (`pubwork`, `pexels_dl`, `prono_dl` → `outils\photos_*`) |
| Photos sources (Pexels, licence libre, usage commercial permis) | `…\outils\photos_afrolook\` (8 photos), `…\outils\photos_pronoflash\` (photos + icône, image de partage et favicon du site) ; liens dans `SOURCES.txt` et les fiches |

Les dossiers `images_test_annonces/` et `images_annonce_pronoflash/` sont **exclus de Git sur ce poste** (`.git/info/exclude`), volontairement.

Liens de l'application Afrolook : Google Play `https://play.google.com/store/apps/details?id=com.afrotok.afrotok` ; App Store `https://apps.apple.com/app/id6811423047`.

Code utile côté annonces : formulaire `site/src/ads.mjs` + `site/static/js/ads.js` (fonctions `adPreview`, `makeAutoBanners`, `drawBanner`, `rowShow`, `bnCount`) ; tag partenaires `site/static/ads/tag.js` (`window.AflAdsPreview`) ; moteur API `app/Http/Controllers/Api/AdsEngineController.php` (`serve`, `brandOf`, bannière prête prioritaire selon `size`) ; enveloppes `app/Ads/Envelopes.php` ; création `app/Ads/Space/Advertisers.php` ; validation `app/Ads/Space/Clean.php` ; page de partage `resources/views/pages/share_link.blade.php` ; cartes de l'application `lib/pages/pub/brand_ad_widgets.dart`.
