# SUIVI STUDIO & TÂCHES À REPRENDRE — AFROLOOK V2
_Dernière mise à jour : 15 octobre 2026 — branche `refonte_claude`_

Document de passation : ce qui est fait dans le Studio Afrolook, comment ça marche, et **toutes les tâches qui restent**, par priorité.

---

## 0. Règles à respecter (obligatoires)

- Tout en **français** : textes de l'app, messages, commits.
- **Proposer avant d'agir** et attendre la validation du propriétaire pour toute nouvelle fonctionnalité ou changement visible.
- **Ne jamais afficher la part de l'application** dans une commission. Exemple : pour un son d'artiste, l'artiste voit « 3 pièces par utilisation » et rien d'autre.
- **Secrets** : ne jamais commiter `functions/.env`, `functions/service-account.json`, `slashatlas/functions/service-account.json`, ni aucune clé. CF_API_TOKEN, CF_ACCOUNT_ID et MINIMAX_API_KEY sont dans Firebase Secrets, jamais dans un fichier.
- SlashAtlas : toujours lancer `node build.mjs` **avant** `firebase deploy --only hosting`.
- Toute nouvelle collection ou tout nouveau dossier Storage contenant des données d'un utilisateur doit être ajouté à la **purge de suppression de compte** (effacement à J+15).

---

## 1. Ce qui est fait (commits du 15/10/2026)

| Commit | Contenu |
|---|---|
| `c6dd6836` | Studio Afrolook : templates prêts à poster, chroniques audio, découpe audio, sons des artistes, page des règles |
| `373fb463` | Fonction serveur `renderStudioMontage` (montage vidéo ffmpeg) |
| `c190886c` | SlashAtlas : séries, rendu des films en arrière-plan, animation 2D (`animationRenderer.js`), numéro de build |
| `092f9cf8` | Studio : enregistrer le montage dans la galerie |

### 1.1 Templates « prêts à poster » (`lib/pages/studio/montage/`)

Accès : création d'un post ou d'une chronique → bouton **Studio** → **« ✨ Templates prêts à poster »**.

| Fichier | Rôle |
|---|---|
| `montage_catalog.dart` | 28 templates (Situations 9, Émotions 8, Culture 5, Fêtes 6) déjà remplis : photo d'exemple (`assets/images/intro*.jpg`, vidéo `assets/videos/intro_video.mp4`), sur-titre, titre, 3 textes de souhait, badge, effet, cadre, teinte. Liste des 54 pays africains et table `kNationalDays` (70 pays : date d'indépendance ou de fête nationale). |
| `montage_state.dart` | Choix de la personne (photo/vidéo, pays, textes, éléments retirés). Noms français des pays lus dans `packages/country_code_picker/src/i18n/fr.json`. Tri : Afrique d'abord. |
| `montage_fx.dart` | 23 effets animés dessinés en `CustomPainter`, fonction de t ∈ [0,1) : **boucle de 3 s parfaite**, chaque mouvement fait un nombre entier de cycles. |
| `montage_canvas.dart` | Rendu en calques `RepaintBoundary` : fond (média + filtre) → teintes (`underlay`) → effet (`fx`) → avant-plan (textes, cadre, logo, @pseudo, filigrane). Le filigrane **« Créé sur Afrolook » est toujours présent**, même publié dans l'app (demande du propriétaire). |
| `montage_export.dart` | Image fixe (capture JPEG 1080 px) ; vidéo : envoi des calques dans `studio_uploads/{uid}/{jobId}/` puis appel de `renderStudioMontage` ; enregistrement en galerie (paquet `gal`, album « Afrolook »). |
| `montage_editor_page.dart` | Éditeur : remplacer la photo ou la vidéo, choisir le format (chronique 9:16 / post 4:5), activer ou couper l'animation, choisir un pays (tous les pays du monde), choisir ou écrire un texte, retirer chaque élément. Bouton « Terminer » → Publier / Enregistrer dans la galerie / Les deux / Continuer à modifier. |
| `montage_gallery_page.dart` | Galerie par catégorie, aperçus animés. |

Le résultat revient en `StudioResult` (image ou vidéo) :
- `userPostForm.dart` le passe à l'onglet Image ou à l'onglet Vidéo (`UserPubVideo` a maintenant `initialVideo` et `initialDescription`) ;
- `chroniqueform.dart` gère déjà les deux cas.

### 1.2 Fonction serveur `renderStudioMontage` (`functions/src/studio/renderMontage.ts`)

- Fonction appelable par l'app, région `us-central1`, 2 Gio, 2 CPU, **5 instances au maximum** (le quota CPU du projet refuse plus), délai 300 s. **Déployée.**
- Entrées : `base.jpg` ou `base.mp4`, `under.png` (vidéo seulement), `fx_000…029.png` (10 images/s), `top.png`. Sortie : `studio_renders/{uid}/{jobId}.mp4`, 720 × 1280 (chronique) ou 720 × 900 (post). Les fichiers envoyés sont supprimés à la fin.
- `buildMontageArgs()` est exportée pour pouvoir tester la commande ffmpeg en local, sans Firebase.

### 1.3 Autres éléments faits plus tôt dans la même session

- Découpe audio façon WhatsApp (`studio_audio_trimmer.dart`), avec début et fin enregistrés dans la chronique (`audioStartMs`, `audioEndMs`).
- Chroniques AUDIO : lecture, défilement automatique et barre de progression dans `chroniquedetails.dart` ; cas AUDIO ajouté dans tous les `switch`.
- Marketplace des sons d'artistes (`artist_marketplace.dart`) : envoi d'un son, « Mes sons », bande dans le feed (`HomeConstPost`), page admin « Sons artistes », choix d'un son dans un post audio, service de crédit artiste. **Voir les bugs ci-dessous.**
- Page Règles & Confidentialité : section « Marketplace des sons artistes ».

### 1.4 Vérifications faites

- `flutter test test/montage_canvas_test.dart` : 56 rendus OK (28 templates × 2 formats). La variable d'environnement `MONTAGE_OUT=<dossier>` enregistre les PNG produits.
- Commande ffmpeg testée en local sur une photo et sur la vidéo du projet : les calques, la boucle et la piste son sont corrects.
- Fonction déployée et accessible (un appel sans connexion renvoie `auth_required`).
- **Pas encore testé sur téléphone** : le propriétaire teste lui-même.

### 1.5 Pièges connus

- Le projet a des fonctions dans **deux régions** (`us-central1` et `europe-west1`). Avant de vérifier une fonction avec `gcloud run services get-iam-policy`, prendre la bonne région dans `firebase functions:list`.
- Firebase ne pose le droit d'appel public (`allUsers` / `roles/run.invoker`) qu'à la **création** d'une fonction, pas lors d'une mise à jour. Le 15/10, `getTeamProfiles` et `getTeamMembers` n'avaient pas ce droit, ce qui provoquait l'erreur « UNAUTHENTICATED » dans « Gestion d'équipe ». C'est réparé.
- Si un déploiement échoue avec « User code failed to load… Timeout after 10000 », relancer avec `FUNCTIONS_DISCOVERY_TIMEOUT=60 firebase deploy --only functions:<nom>`.
- Flutter : `audio_waveforms` et `audioplayers` exportent tous les deux `PlayerState`, donc importer avec `import 'package:audio_waveforms/audio_waveforms.dart' hide PlayerState;`. Couleurs du Studio : `const _c = AppColors.dark;`.

---

## 2. Tâches restantes — par priorité

### P1 — Bugs de la marketplace des sons d'artistes (à corriger avant toute mise en ligne)

1. **Index Firestore composites manquants** pour `artist_sounds` : `status + validatedAt desc`, `userId + createdAt desc`, `status + createdAt desc`. Sans eux, le feed, « Mes sons », la page admin et le choix d'un son dans un post audio échouent. À ajouter dans `firestore.indexes.json`, puis déployer.
2. **Mauvaise collection** dans `lib/services/artist_sound_usage_service.dart` : il écrit dans `users` au lieu de `Users`, donc le paiement de l'artiste échoue.
3. **Sécurité** : le crédit de pièces et la validation admin se font depuis l'app, et la règle générale de `firestore.rules` permet à tout utilisateur connecté d'écrire dans `artist_sounds` (il pourrait valider son propre son). À faire :
   - passer le crédit et la validation par des fonctions serveur (sur le modèle de `stickerPayments.ts` : `giftCoinsBalance` et `totalCoinsEarnedFrom…`) ;
   - interdire l'écriture directe dans `artist_sounds` (liste d'exclusion de la règle générale), sauf la création par le propriétaire du son.
4. **Purge de suppression de compte** : ajouter `artist_sounds` (les sons de la personne), `studio_uploads/{uid}` et `studio_renders/{uid}`.
5. **Nettoyage de `studio_renders/`** : les vidéos s'accumulent. Ajouter une règle de cycle de vie du bucket ou une tâche planifiée qui supprime les fichiers de plus de 7 jours (la vidéo est retéléchargée par l'app puis republiée dans les posts ou chroniques).

### P2 — Retours du test sur téléphone (le propriétaire teste)

- Galerie, éditeur, export image, export vidéo (avec connexion), enregistrement en galerie (permissions Android et iOS : le paquet `gal` est déjà utilisé par le Studio Cartes), publication en post vidéo et en chronique.
- Relire les dates de `kNationalDays` (70 pays) avant la mise en ligne.

### P3 — Musique d'ambiance des templates (demandée, à faire après)

En attendant une vraie bibliothèque musicale, chaque template doit avoir une musique d'ambiance selon l'émotion. Aujourd'hui, seul un libellé « Son suggéré » s'affiche. Plan :

1. Remplacer `sound` par une **ambiance** (triste, joyeux, romantique, festif, calme, énergique, nuit/afrobeat, spirituel).
2. **Bibliothèque de sons** : titre, ambiance, source (`afrolook` / `artiste` / `ia`), licence, durée, url, validé. Le template prend un son validé de son ambiance ; la personne peut le changer, le couper (`StudioAudioTrimmer`) ou le retirer.
3. **Export** : `renderStudioMontage` reçoit le son et son début/fin, puis le mixe avec un fondu. Pour une vidéo : remplacer ou mélanger avec le son d'origine. Pas de son sur une image fixe.
4. **Artistes et créateurs** : à l'envoi, choix **🎤 Musique réelle** ou **🤖 Musique IA** (avec l'outil utilisé) ; attestation des droits obligatoire (pour l'IA : l'outil autorise l'usage commercial) ; choix d'une ou plusieurs ambiances ; badge 🎤/🤖 visible ; type affiché à l'admin. Une utilisation dans un montage crédite 3 pièces à l'artiste.
5. Mettre à jour la page Règles & Confidentialité.

**Questions à poser au propriétaire avant de coder :**
- Une musique IA rapporte-t-elle autant à son créateur qu'une musique réelle ?
- Afrolook génère-t-il lui-même des musiques IA pour la bibliothèque (quel outil, quel coût) ?
- D'où viennent les premiers sons de la bibliothèque ?

### P4 — Studio : fonctions proposées mais pas encore validées ni codées

- « Mes créations » : brouillons (proposition : 20 au maximum), sauvegarde automatique à la publication, fenêtre « Garder le brouillon ? » en quittant. **Attendre la validation du propriétaire.**
- Compression automatique avant envoi (WebP, H.264/H.265, AAC), proposée dans la v4 de la proposition.

### P5 — Travaux en attente hors Studio

1. **Pages vidéo inutilisées à supprimer**. Garder `youTube_video_card.dart`, `postDetailsVideo.dart` et `post_video_format_tel_details.dart`. Les autres candidates sont à vérifier avec `flutter analyze lib` avant de les retirer.
2. **Textes des stores** (positionnement « réseau social qui paie les likes, vues et cadeaux ») : en attente de validation, puis traduction en 7 langues.
3. **Fiche App Store traduite** (version 2.0.5) et réponse à Apple sur les achats intégrés. Ne rien soumettre sans l'accord du propriétaire.
4. **Taux de change** : vérifier que `AppConfig/exchangeRates` est bien rempli chaque jour par `updateExchangeRates`.
5. **Accès API Play Console** : la clé du compte de service est fournie par le propriétaire, **hors dépôt**. Au premier essai, l'API répondait 403 : le compte n'était pas encore invité dans la Play Console.
6. **Règle Storage temporaire** `user_profile/` (création sans connexion) : à retirer quand toutes les installations auront la version corrigée de l'inscription.

### P6 — SlashAtlas (à faire)

1. **MiniMax H3** (vidéo 2,5D/3D avec synchronisation des lèvres) :
   - API `https://api.minimax.io/v2/video_generation`, modèles `MiniMax-H3` / `MiniMax-H3-Max` ;
   - état final à détecter : `"succeeded"` ;
   - clé dans le secret `MINIMAX_API_KEY` (déjà déclarée dans `slashatlas/functions/index.js`) ;
   - à créer : `h3Renderer.js`, un nouveau type `film_h3` et une page « Mes personnages ».
   
   Ne pas toucher au moteur d'animation 2D canvas existant. Le vieux système FLUX + Ken Burns (diaporama) doit disparaître.
2. **Dialogue entre personnages** : tableau `dialogue` dans les scènes (`char`, `texte`, `voix`) ; le personnage qui parle passe en état `talk` ; une voix TTS par personnage. Fichiers à modifier : `filmRenderer.js`, `index.js`, `studio-film.js`.

---

## 3. Fichiers locaux non commités (normal)

- `.claude/launch.json`, `.claude/settings.local.json` : réglages propres à la machine.
- `.firebase/hosting.*.cache` : cache de déploiement.
- `slashatlas/functions/check-job-status.mjs`, `slashatlas/functions/test-serie-episode.mjs` : scripts de test locaux, qui lisent `service-account.json` (fichier exclu du dépôt).
