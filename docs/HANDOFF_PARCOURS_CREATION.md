# Passation du 05/11/2026 : parcours « Créer un post » + récapitulatif depuis le mardi 03/11

> Fichier écrit à la demande du propriétaire parce que le quota de l'agent précédent est presque épuisé. **Un autre agent reprend le travail.**
> Il complète `docs/PROJET_MEMOIRE.md` (mémoire unique) et `docs/PROMPT_REPRISE_AGENT.md` (prompt de reprise du 30/10, toujours valable pour les règles).
> Date de rédaction : jeudi 05/11/2026, en fin de journée. Dépôts : application `D:\bienvenu\Projets\otherProjets\afrolook\V2\afrolookofficiel_v2` (branche `main`),
> API `D:\bienvenu\Projets\otherProjets\afrolook\V2\afrolook-api` (branche de travail `develop`, la production se déploie depuis `main`).

---

## A. MESSAGE À DONNER À L'AGENT (copier/coller)

> Tu reprends le projet **Afrolook** avec le propriétaire (il écrit en français, tu réponds en **français avec les accents**, simplement et directement).
> **Avant toute chose, lis dans cet ordre** : 1) `CLAUDE.md` à la racine ; 2) `docs/PROJET_MEMOIRE.md` (mémoire unique : règles, état, section 7.0 « Reprise », journal en **bas** du fichier) ;
> 3) **`docs/HANDOFF_PARCOURS_CREATION.md`** (le fichier que tu lis : tout ce qui a été fait depuis mardi 03/11, l'état exact du chantier en cours et la liste de ce qu'il reste à faire) ;
> 4) `docs/SECURITE_API.md` avant de toucher aux paiements, aux comptes ou aux règles ; 5) `docs/PROMPT_REPRISE_AGENT.md` section 2 (règles du propriétaire).
> Puis ouvre **la proposition visuelle validée** « Parcours de création » : artifact privé https://claude.ai/artifact/5Xab3gcYPmeAR7x22et34d (version 2) ; le propriétaire en a aussi une copie
> `D:\Personnel\Downloads\Parcours de création.html`, identique à la proposition publiée, et **une copie est dans le dépôt : `docs/maquettes/parcours_creation.html`** (à ouvrir dans un navigateur : les écrans téléphone sont dans la page, avec les onglets Vidéo / Photo / Audio / Texte / Carte).
> Pour lire l'artifact avec l'outil Artifact : `action: "read"` avec l'adresse ci-dessus (il appartient au compte du propriétaire). **C'est la référence : chaque écran de l'application doit lui ressembler**
> (le propriétaire a constaté que ce n'était pas encore le cas pour la page de publication et le Studio, voir section D).
> **Règles à ne jamais oublier** : poser les questions avant d'agir ; proposer avant tout changement important ; **ne pas committer ni pousser sans demande explicite** ; **ne jamais déployer en production**
> (le propriétaire déploie lui-même) ; aucun secret dans le dépôt, les messages ou les captures ; tout texte visible passe par `context.tr('français', {args})` ; la couleur jaune est un fond (texte sombre dessus),
> `accentText` (ambre) pour le texte et les icônes jaunes ; pas d'animation par défaut dans le Studio ; clair **et** sombre partout. À la fin de ta session : mets à jour `docs/PROJET_MEMOIRE.md` (journal) et ce fichier.
> **Ton travail immédiat** : le chantier « parcours de création » : finir les écrans qui ne ressemblent pas encore à la proposition (liste priorisée en section E), puis les tests, puis demander au propriétaire s'il veut le commit/push.

---

## B. Ce qui a été fait depuis le mardi 03/11/2026 (récapitulatif)

### Mardi 03/11 (déployé ou commité)
- **Site (régie Afrolook Ads)** : solde annonceur en FCFA, recharge Mobile Money et carte (fenêtre adaptée au mobile, numéro sans indicatif accepté, roue sur le bouton Payer, message clair si le numéro n'existe pas chez l'opérateur), arrêt et suppression des campagnes, page **Annoncer** (WhatsApp/Telegram/Facebook, simulateur d'audience, exemples d'affichage), liens suivis `/p/` par l'API, alerte « Recharger maintenant » si solde insuffisant, adaptation au téléphone (320 px).
- **API** : compression des vidéos d'annonces (720 p, toutes les 5 min) ; **Groupes officiels** (tout le monde y entre à la connexion, page admin) ; **suivi de la page Travail** pour l'administration ; audience publique (prix de 1 000 personnes) ; **Torox** : offres à étapes (progression par personne, annulation par étape) et adresse du flux avec les étapes ; **retrait minimum 5 000 F** ; **modération** (un compte d'équipe peut supprimer la publication d'un autre, avec trace) ; FeexPay : numéro complet avec indicatif.
- **Application 2.0.19 (build 270, le nom reste 2.0.18 par décision du propriétaire)** : bouton Suivre selon la liste d'abonnements, suppression d'une publication par un modérateur, fiche d'offre des tâches partenaires avec les étapes, **messages dans l'application (Firebase In-App Messaging)** avec ciblage (pays, langue, abonnement, équipe), fenêtre Premium/Gold quand une vidéo dépasse la limite du plan, boost « Diffuser partout » (ALL), transactions cliquables dans la monétisation.
- **Mémoire** : section 7.0 « Reprise » écrite.

### Mercredi 04/11
- **Régie/administration** : logo obligatoire du diffuseur, alertes d'équipe (notification + e-mail) à chaque profil annonceur ou diffuseur, onglet Annonces de l'administration, tous les pays, image obligatoire, **Mes gains et retraits du diffuseur** (file de retraits de l'équipe).
- **Application** : les pubs d'Afrolook se chargent à l'avance et passent en repli d'Appodeal/AdMob ; **la configuration des pubs vient de l'API** (réglage `ads_client`, plus de Firebase) ; offre gratuite = une seule annonce de 14 jours non renouvelable.
- **Partage et gagne** : la part du parrain (10 % du gain du filleul) est versée côté API ; CORS strict pour l'application web (`afrolookmedia.com/app`) ; écran d'attente web pendant le chargement de `/app`.
- **iOS 2.0.19 envoyée à la validation d'Apple.**

### Jeudi 05/11 (aujourd'hui)
- **Production (3 bugs)** : FeexPay refusait le pays envoyé en toutes lettres (« Togo ») → l'API accepte noms et codes (`Deposits::countryCode`), liste des dépôts en cours ; transactions en attente ; page /ads/espace « Impossible de charger ton profil ».
- **Annonces unifiées (7 types)** : enveloppes de diffusion payées depuis le solde annonceur (`Envelopes`, migrations `…000100` à `…000500`), 3 diffusions (Afrolook, partenaires au CPM, partage au clic), formulaire du site en 4 étapes, vérification quotidienne des liens, cartes de marque dans l'application, **annonces offertes à l'équipe d'argent + recharge gratuite d'un solde par e-mail** (admin), **fin automatique d'une campagne de partage quand son budget est épuisé**, **estimation des clics et des personnes touchées (2,2 % à 3,8 %)** donnée avant de payer, contact **WhatsApp du support +228 71 64 54 03** partout sur le site.
- **Application** : fil **Sport infini** comme l'accueil (fil « pour toi » filtré par thème, jamais de post indisponible ni déjà vu) ; widget « Travaille et gagne » dès le 1er post ; **carte d'actualité du journal tous les 6 posts** (6e, 12e, 18e…).
- **Journal d'actualités** : le propriétaire a ajouté lui-même le compte et le jeton Cloudflare sur le serveur (les articles avaient 3-4 jours de retard).
- **Parcours de création** (chantier en cours, section C et suivantes). Tout ce chantier est **non commité**.
- Commits du jour : app `54fb5bbf` (carte d'actualité tous les 6 posts) ; API `8e3dca3` (fin auto + estimations). **Déploiements faits par le propriétaire** : API et site (`firebase deploy --only hosting:vitrine`) déployés le 05/11 en milieu de journée.

---

## C. Le chantier « parcours de création » : décisions validées par le propriétaire (05/11)

1. **Un seul parcours** réunit page de publication, Studio et Cartes. Le « + » ouvre un menu à **deux choix** : *Créer un post*, *Passer en live*. Défi et Canal gardent leur contexte et sautent le menu.
2. **« Que créer ? »** : bandeau « Fête du jour » (carte), grande tuile **Vidéo** (filmer d'abord), tuiles Photo / Audio / Texte / Carte, bande « Modèles prêts à poster ».
3. **Caméra intégrée** (vidéo 15/30/60 s et photo), enregistrements **toujours prioritaires**. **Galerie : 3 médias par jour** (jour UTC) ; au-delà il faut se filmer. **Les canaux n'ont aucune limite de galerie et pas de live.**
4. **Mention « Fait sur Afrolook »** sur tout ce qui est **filmé, enregistré OU retouché dans notre Studio** (demande du 05/11 en fin de journée). Origines côté serveur : `captured` (filmé/enregistré : priorité 1,35, aucun délai), `edited` (média de la galerie retouché dans le Studio : mention + priorité 1,1, **compte dans les 3/jour et garde le délai**), `imported` (galerie), `null` (texte, carte, lien, ancienne version : aucune règle).
5. Posts-liens (YouTube…) : délai ×3 et classement plus bas. **Appels à poster** dans les fils (14 phrases variées, 3 par jour au plus, jamais sur le web).
6. **Studio sobre** : aucun effet animé par défaut, 8 « looks » de couleur pro (naturel, doré, cinéma, mono, mat, vif, terre, nuit). Le propriétaire veut maintenant un Studio « digne de TikTok ou CapCut, juste le nécessaire », en **clair et sombre**.
7. **Effets de voix** choisis par la personne (grave, aiguë, radio, écho, salle, anonyme), **jamais de clonage de voix**, mention « Voix modifiée ». **La personne doit entendre le vrai rendu avant de publier** (demande du 05/11) : implémenté (le serveur produit le rendu, elle l'écoute, puis valide).
8. **Modèles prêts à poster** : la **photo de profil** de la personne remplace la photo d'exemple dans les aperçus de la galerie et dans l'éditeur de modèle (demande du 05/11).
9. **Décision en attente** : donner un bonus en pièces/argent aux contenus originaux (recommandation : visibilité seulement pour commencer).

---

## D. Comparaison honnête : ce qui existe vs la proposition validée

Référence : écrans 1 à 9 du parcours Vidéo, puis Photo, Audio, Texte, Carte de la proposition.

| Écran de la proposition | État dans l'application | Écart |
|---|---|---|
| 2. Menu du « + » (2 choix) | ✅ `create_menu_sheet.dart` | — |
| 3. Que créer ? | ✅ `create_hub_page.dart` (bandeau fête, tuile vidéo, tuiles, bande de modèles avec photo de profil) | à comparer visuellement sur téléphone |
| 4. Caméra (durées, retourner, flash, galerie, gros bouton, VIDÉO/PHOTO) | ✅ `create_camera_page.dart` | il manque le bouton « ✦ » (effets/filtres) ; **à tester sur un vrai téléphone** (jamais testée hors test unitaire) |
| 5. Éditeur (outils Modèles, Musique, Texte, Effets, Couper + barre + Refaire/Suivant) | 🟡 refait aujourd'hui (`create_editor_page.dart`, clair/sombre) avec **3 outils réels** : Modèles, Musique, Effets | **manquent Texte et Couper** ; Musique/Effets ouvrent l'éditeur de montage plein écran au lieu d'une feuille en bas |
| 6. Outil Modèles (feuille en bas : Situations, Émotions, Fêtes, Culture) | 🟡 ouvre `MontageGalleryPage` plein écran | à transformer en feuille en bas sur la vidéo |
| 7. Outil Musique (Gratuites/Artistes, « Garder le son de ma vidéo ») | 🟡 section musique de `MontageEditorPage` | à mettre en feuille ; réglage « garder le son » existe (`keepVideoAudio`) |
| 8. Préparation (anneau + barre) | ❌ ce sont les fenêtres de l'ancien éditeur | à créer : écran « Préparation de ta vidéo » |
| 9. **Formulaire unique** | ✅ **refait aujourd'hui** : `create_publish_page.dart` (aperçu + description, type de publication, pays, note « Fait sur Afrolook / Voix modifiée / modèle / musique », bouton Publier fixe, clair et sombre, 3 tests) | manque : miniature personnalisée, monétisation, création d'un Défi (type DEFI), publicité (ancien mode « publicité »), « regarder une pub » pour sauter le délai (le serveur reste maître du délai) |
| Photo : grille numérotée « Récents ▾ / Suivant » | 🟡 sélecteur système (`pickMultiImage`) | à remplacer par la grille de la maquette |
| Photo : bandeau « Avec musique : vidéo de 15 s » | ❌ | à ajouter dans l'éditeur |
| Audio : enregistrer (onde + 0:48 / 3:00 + micro) | 🟡 `create_voice_page.dart` : micro + temps + réécoute, **pas d'onde** | ajouter la forme d'onde |
| Audio : « Ton audio » (Couper, Pochette, Refaire/Suivant) | ❌ remplacé par **« Choisis ta voix »** (`voice_effect_page.dart`, demande du propriétaire) | ajouter Couper et Pochette autour |
| Texte : papier coloré + pastilles de couleurs + modèles (Citation, Annonce, Humeur, Pensée) | ❌ le texte va directement au formulaire (zone de saisie simple) | à créer |
| Carte : composer puis « Aperçu et prix » | ❌ `CardEntry.openCompose` existant, pas restylé | à restyler selon la maquette |
| Studio « complet » (TikTok/CapCut, clair et sombre) | 🟡 toutes les couleurs du Studio suivent maintenant le thème (`lib/pages/studio/studio_theme.dart`, `syncStudioColors`) | **pas vérifié visuellement** : des `Colors.white/black` en dur peuvent rester ; **le Studio doit être refait** (voir E) |

---

## E. À FAIRE, par priorité

1. **Studio et éditeur unique (le propriétaire insiste)** : refaire pour de bon l'éditeur selon la proposition (feuilles en bas pour Modèles/Musique/Effets, outils **Texte** et **Couper**, barre de lecture, écran « Préparation »). Style TikTok/CapCut sobre, **clair et sombre**, mention « Fait sur Afrolook » sur tout ce qui est enregistré ou édité. Vérifier le thème clair du Studio ancien (`studio_entry_page`, `studio_*_editor`, `montage_*`).
   - **Couper** (découpe vidéo) : aucun outil côté application (`ffmpeg_kit` est commenté dans `pubspec.yaml`). Piste : endpoint API `POST /studio/trim` (ffmpeg, même modèle que `StudioVoiceController`) ou un paquet de découpe.
   - **Texte sur vidéo/photo** : le montage « sans habillage » (`kPlainTemplate`) masque tous les calques ; prévoir un calque texte.
2. **Écrans Texte, Carte, Photo (grille), Audio (onde, Couper, Pochette)** selon la proposition (tableau D).
3. **Répondre en vidéo (15 s)** : le serveur est prêt (voir F). Reste l'application : bouton sur les posts, `CreateHubPage(start: video, replyToPostId)` avec caméra limitée à 15 s (`CreateCameraPage.maxSeconds` existe), `PostReplyLink.set(id)` (déjà créé dans `lib/services/post_source_link.dart`, consommé par `PostsApi.create`), ligne **« En réponse à @pseudo »** sous le post (champ `reply_to` rendu par l'API), notification `VIDEO_REPLY` (textes en 8 langues déjà dans `PushTexts`).
4. **Étiquette « Voix modifiée »** sur les posts audio : l'API rend `voice_effect` ; ajouter `Post.voiceEffect` (modèle + `post_mapper.dart`) et un petit widget dans la page du post audio.
5. **Sous-titres automatiques de l'audio** : pas commencé. Plan : Workers AI `@cf/openai/whisper` via les comptes `NEWS_AI_ACCOUNTS` (`App\News\Ai`, rendre `addUsage` public), **réglage `studio.transcribe.enabled` désactivé par défaut** (le quota neurones gratuit est petit et partagé avec le journal), plafond de secondes par jour et par personne, colonne `posts.transcript`.
6. **Filtres sur le visage (façon Snapchat)** : pas commencé. Demande de l'ML sur l'appareil (ML Kit) et des tests sur vrai téléphone ; proposer d'abord une version légère (cadres/masques photo).
7. **Traductions** des nouveaux textes (`lib/l10n/tr_*.dart`, 8 langues, au moins l'anglais) : aucun des textes du parcours n'est encore traduit.
8. **Entrées hors parcours** : l'ancienne page `UserPostForm` (cinq onglets, `lib/pages/userPosts/`) sert encore aux entrées qui ne passent pas par `openCreateForm` (route `/user_posts_form` redirige déjà vers le hub). Ne la supprimer qu'après accord et vérification (le Défi se crée encore par elle).
9. **Décision en attente du propriétaire** : bonus en argent/pièces pour les contenus originaux.
10. **Test sur un vrai téléphone** de tout le parcours (caméra, micro, effets de voix, modèles avec photo de profil, mention).

---

## F. État du code (TOUT EST NON COMMITÉ)

### API (`afrolook-api`, branche `develop`) — suite complète verte (1211 réussis), puis +11 tests ajoutés (tous verts)
Fichiers modifiés : `app/Feed/ForYou.php`, `app/Http/Controllers/Api/PostController.php`, `app/Notifications/PushTexts.php`, `config/app.php`, `routes/api.php`.
Nouveaux : `app/Posts/Capture.php`, `app/Studio/VoiceEffects.php`, `app/Http/Controllers/Api/StudioVoiceController.php`, migrations `2026_11_05_000600_posts_capture_source.php` et `2026_11_05_000700_posts_reply_and_voice.php`, tests `PostCaptureTest` (8), `PostReplyTest` (3), `StudioVoiceTest` (4, **le vrai ffmpeg traite les 6 effets**).
- `POST /v1/posts` accepte `capture_source` (captured|imported|edited), `reply_to_id` (le post visé doit être visible, sans blocage, et la réponse doit être une **vidéo** : sinon 422 `reply_target_invalid` / `reply_needs_video`), `voice_effect` (gardé seulement sur un audio). Réponse : `capture_source`, `voice_effect`, `reply_to {id, author{id, username}, excerpt}`.
- `GET /v1/posts/quota` (imports restants), `POST /v1/studio/voice` (`upload_id` + `effect` → audio traité déposé sur R2, 6 requêtes/min), `GET /v1/studio/voice/effects`.
- Quota d'imports : `IMPORT_POSTS_PER_DAY` (3), délai des posts-liens ×`LINK_POST_COOLDOWN_FACTOR` (3). Staff et canaux exemptés.
- **Ordre de déploiement** : API d'abord (2 migrations), puis nouvelle version de l'application. Une ancienne version de l'application n'envoie rien : aucune règle ne s'applique, rien ne casse.

### Application (`afrolookofficiel_v2`, branche `main`)
Nouveaux : `lib/pages/create/` (`create_menu_sheet`, `create_hub_page`, `create_camera_page`, `create_editor_page`, `create_voice_page`, `voice_effect_page`, `create_publish_page`, `create_flow`, `create_result`), `lib/services/post_source_link.dart` (`PostSourceLink`, `PostVoiceLink`, `PostReplyLink`), `lib/services/api/studio_voice_api.dart`, `lib/widgets/original_badge.dart`, `lib/widgets/feed/sections/post_call_card.dart`, `lib/pages/studio/montage/montage_look.dart`, `lib/pages/studio/studio_theme.dart`, tests `create_flow_test`, `create_publish_test`, `montage_sobre_test`.
Modifiés : accueil/Sport (`homeScreen`, `homeSportPost`, `HomeConstPost`), `main.dart`, `detailsCanal`, `defi_ui`, `userPostForm` (mode parcours + audio prêt), `userPostAudioTab` (audio pré-rempli), `posts_api.dart`, `post_mapper.dart`, `model_data.dart` (`captureSource`), `postWidgetPage.dart` (badge), studio/montage (`animated=false`, calque FX masqué, looks, `focus`, `usedOwnMedia`, photo de profil dans les modèles), `docs/PROJET_MEMOIRE.md`.
**Ne pas commiter** avec le reste : `pubspec.yaml` (version 2.0.20+271, travail du propriétaire), `macos/Flutter/GeneratedPluginRegistrant.swift` (régénéré), `docs/video_*`, `docs/ads_visuels/`.
Tests : `flutter test test/create_flow_test.dart test/create_publish_test.dart test/montage_sobre_test.dart` verts ; `feed_slot_planner_test` échoue **depuis avant** (sans rapport).

---

## G. Pièges techniques (déjà rencontrés)

- **Une seule suite de tests API à la fois** (base Postgres de test partagée) : deux lancements en parallèle provoquent des interblocages (un a échoué ainsi aujourd'hui, repassé seul).
- Git Bash : les here-documents avec apostrophes cassent (« unexpected EOF ») ; écrire un script avec l'outil Write puis l'exécuter. Les titres de tests Pest ne doivent pas contenir d'apostrophe simple.
- `flutter test` relance la résolution des dépendances ; `git stash pop` peut être bloqué par `macos/Flutter/GeneratedPluginRegistrant.swift` (le restaurer d'abord).
- Après `node build.mjs` du site, relancer `node with-app.mjs` (sinon `/app/` disparaît) ; monter `ASSET_V` quand un script du site change (actuellement 51).
- Dans les tests Flutter : utiliser la langue `fr` et `GlobalMaterialLocalizations.delegates` ; `UserAuthProvider` ne s'instancie pas sans Firebase (le formulaire unique accepte donc `me:` en paramètre de test).
- Couleurs : jaune = fond seulement (texte sombre dessus), `accentText` pour le texte/icône jaunes, vert principal, rouge danger, barre du haut grise. **Toujours `AppColors.of(context)`** (jamais `AppColors.dark` figé).
- Le propriétaire n'aime pas les images dans le chat pour les propositions : utiliser des **artifacts publiés**. Ne jamais afficher la clé App Store (`AuthKey_T42B8B48XF.p8`) ni aucun secret.

## H. Règles du propriétaire rappelées
Poser les questions avant d'agir ; proposer avant de changer ; ne pas commiter/pousser sans demande ; il déploie lui-même (API : `sudo -u deploy -H env APP_DIR=/var/www/afrolook-api APP_HOST=api.afrolookmedia.com bash /var/www/afrolook-api/deploy/deploy.sh main` ; site : `firebase deploy --only hosting:vitrine --project afrolooki`) ; « Afrolook Ads » pour la régie, jamais la part gardée ; pas de configuration depuis Firebase ; chaque avancement s'annonce avec « point N sur N » quand une liste numérotée est en cours.

---

## I. Reprise du 06/11/2026 : ce qui a été fait depuis la passation (TOUT EST NON COMMITÉ)

Décisions du propriétaire (06/11) : on suit les recommandations ; **les écrans doivent exister en clair ET en sombre, textes bien lisibles** ; respecter la proposition validée (consultée en entier le 06/11 : écrans 1 à 9 et onglets Photo / Audio / Texte / Carte, mesures relevées dans son CSS : lignes de champ rayon 12, fond `#1D2024`, contour `#2F343A`, carte de note crème `#EFEBDF`, jaune `#FFC400`, bouton Publier rayon 14).

**Fait** (tests : `create_editor_test`, `create_text_test`, `create_voice_test`, `prepare_screen_test`, `post_reply_voice_test`, `tr_creation_test` + les 3 tests précédents, tous verts ; `dart analyze lib` = 0 erreur) :
- **Formulaire unique** (`create_publish_page.dart`) restylé selon l'écran 9 (titre centré, miniature + description, lignes Type de publication / Pays sans icône, note crème avec texte sombre, Publier jaune). Toutes les données demandées sont conservées.
- **Éditeur unique** (`create_editor_page.dart`) refait selon l'écran 5 : média plein écran, voiles haut et bas, bouton Couper rond avec la durée, **5 outils** (Modèles, Musique, **Texte**, Effets, **Couper**), barre de lecture jaune, Refaire / Suivant ; bandeau « Avec musique : vidéo de 15 s » pour une photo. Commandes blanches sur voile sombre : lisibles sur toute image, en clair comme en sombre.
- **Texte** : nouveau calque de texte libre du montage (`MontageState.freeText/freeColor/freePos`, `kFreeTextColors`, section « Texte sur l'image » de `MontageEditorPage`, rendu dans `montage_canvas.dart`), y compris pour le modèle « sans habillage ».
- **Couper** : API `POST /v1/studio/trim` (`StudioTrimController`, test avec le vrai ffmpeg, vidéo et audio) + client `lib/services/api/studio_trim_api.dart` + feuille `trim_sheet.dart` (vidéo dans l'éditeur, audio dans l'écran Audio). **L'API doit être déployée avant la nouvelle version de l'application.**
- **Écran Texte** (`create_text_page.dart`) : papier de couleur, 5 pastilles, 4 façons d'écrire (Citation, Annonce, Humeur, Pensée). « Suivant » transforme le papier en image et ouvre le formulaire avec le texte dans la description (**le post devient donc un post image** : décision de ma part, conforme à la maquette où la miniature du formulaire est le papier ; à confirmer).
- **Écran Audio** (`create_voice_page.dart`) : onde qui bouge pendant l'enregistrement, minuteur « 0:48 / 3:00 », micro rouge, bouton « Importer un fichier » ; puis « Ton audio » avec onde de lecture, **Couper** et **Pochette** (la pochette part avec le post comme image), Refaire / Suivant.
- **Écran Préparation** (`prepare_screen.dart`) : plein écran, anneau, message, barre qui avance (estimation de 15 s, bloquée à 92 % tant que le serveur n'a pas répondu) ; remplace l'ancienne fenêtre d'attente de l'éditeur de montage.
- **Répondre en vidéo** : bouton caméra dans la barre d'actions d'un post (`reply_video_button`), `CreateHubPage(replyToPostId:)` (caméra limitée à 15 s, `PostReplyLink`), ligne « En réponse à @pseudo » (touchable), modèle `Post.replyTo…`, mapper de l'API.
- **Étiquette « Voix modifiée »** (`VoiceChangedBadge`, `Post.voiceEffect`) sous le nom de l'auteur.
- **Traductions** : `lib/l10n/tr_creation.dart` (anglais fait pour tous les textes du parcours ; es, pt, de, ar, zh, sw retombent sur l'anglais).
- **Thème clair du Studio** : les textes, icônes et pistes posés sur une surface du thème dans les anciens éditeurs (`studio_video_editor`, `studio_image_editor`, `studio_text_editor`, `studio_audio_editor`, `studio_audio_trimmer`) utilisent maintenant les couleurs du thème. Les blancs sur dégradé, sur vidéo ou sur photo sont volontairement gardés.

**Reste à faire**
1. **Photo : grille numérotée** (« Récents ▾ / Suivant ») : impossible sans plugin de galerie (`photo_manager` ou équivalent + permission de lecture des images) ; **à valider par le propriétaire** (ajout d'une dépendance). Aujourd'hui : sélecteur système.
2. **Outils Modèles et Musique en feuille en bas** (écrans 6 et 7) au lieu du plein écran ; réglage « Garder le son de ma vidéo » à remonter dans la feuille Musique.
3. **Carte** (composer puis « Aperçu et prix ») : restyler `CardEntry` selon les écrans de la proposition.
4. Bouton « ✦ » de la caméra (effets/filtres), **filtres de visage**, **sous-titres automatiques** : volontairement reportés (voir section E, points 5 et 6).
5. Ancienne page `UserPostForm` : encore utilisée par le Défi ; ne la retirer qu'après accord.
6. **Essai sur un vrai téléphone** : caméra, micro, onde en direct, découpe vidéo et audio (appel réel à l'API), Préparation pendant un vrai montage, « Répondre en vidéo », texte transformé en image.
7. Traductions es, pt, de, ar, zh, sw des nouveaux textes.

### Ajout du 06/11/2026 (soir) : placer et décorer dans le Studio
- **Déplacer soi-même** le pseudo, les j'aime/commentaires, le texte libre, le logo Afrolook et le bloc de texte du modèle : on touche et on glisse sur l'aperçu (`MontageCanvas.onMove`, état `MontageState.moved`, placement `_Movable` / `_SlotDelegate`). **L'élément est toujours ramené entièrement dans le cadre** (marge de 1,2 %) : il ne peut pas se perdre ; test `montage_stickers_test`. Bouton « Tout remettre en place ».
- **Pack d'autocollants prêt à choisir** (`montage_stickers.dart`) : 9 thèmes (Visages, Cœurs, Fête, Afrique avec drapeaux, Sport, Gestes, Objets, Pastilles de texte NOUVEAU/PROMO/-50 %…, logo Afrolook), jusqu'à 12 par montage ; on les glisse, on les pince pour les agrandir (ou boutons − / +), on les retire ; le dernier ajouté est au-dessus. Ils font partie du calque d'avant-plan : ils sont exportés tels quels (image et vidéo).
- Section « Placer et décorer » de l'éditeur de montage (`focus: 'stickers'` possible). Pas encore d'outil dédié dans la barre de l'éditeur plein écran (à décider).
