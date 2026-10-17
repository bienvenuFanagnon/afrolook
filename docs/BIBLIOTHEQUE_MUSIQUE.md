# Afrolook Musique — plan détaillé et analyse de sécurité

Présentation : « Afrolook Musique » (15 diapositives, publiée en artefact). Ce document est le plan technique complet.

## 1. Où on en est (déjà en ligne)

| Élément | État |
|---|---|
| 17 musiques gratuites synthétisées (sans droits) | en ligne (Storage `studio_music/`) |
| Sons d'artistes : dépôt gratuit ou payant, écoute admin, validation | en ligne |
| Original privé + extrait public de 30 s | en ligne |
| Détection des doublons (SHA-256 + empreinte audio) | en ligne, testée |
| Paiement à l'utilisation par le serveur (5 pièces, 3 pour l'artiste) | en ligne, testé |
| Signalements (3 = suspension), suppression stricte | en ligne, testés |
| Carte musique dans le fil, page du son, « Créer un post avec ce son », posts du son (5 par 5) | en ligne côté serveur ; app à publier |

Gains d'un artiste : 3 pièces **gagnées** par utilisation payante, créditées tout de suite dans `Users.giftCoinsBalance`, convertibles par `convertGiftCoins` (25 pièces = 10 FCFA) puis retirables. Aucun gain quand le son est gratuit ou quand l'artiste utilise son propre son (c'est gratuit pour lui, mais il ne gagne rien).

## 2. Modèle de données (extension)

`artist_sounds/{id}` (existant) gagne :
- `useCoins` (prix d'utilisation, 2–20, défaut 5) et `saleCoins` (prix de vente, 0 = non vendu, sinon 50–500) ;
- `countries[]` (pays visés) et `allCountries` ;
- `allowFileExport` (l'artiste autorise le fichier libre) ;
- `saleCount`, `favCount`, `playCount` (compteurs serveur).

Nouvelles collections (écriture serveur uniquement, comme `ArtistSoundUses`) :
- `MusicLibrary/{uid}_{soundId}` : achat (prix payé, date, appareil) ;
- `MusicFavorites/{uid}_{soundId}` : favori (écriture client permise pour son propre uid, lecture propriétaire) ;
- `MusicDownloads/{uid}_{deviceId}_{soundId}` : téléchargements autorisés (limite d'appareils) ;
- `MusicPlays/{day}_{soundId}` : écoutes agrégées (statistiques artiste).

## 3. Les deux prix

| Prix | Donne accès à | Part de l'artiste |
|---|---|---|
| Utilisation (`useCoins`) | Utiliser le titre dans un post du Studio | 60 % (3 sur 5) |
| Vente (`saleCoins`) | Titre complet dans la bibliothèque, hors ligne | 60 % |
| Gratuit | Écoute et usage libres | 0 |

Achat = callable `musicBuy({soundId})` : transaction unique (solde ≥ prix, pas déjà acheté, son validé et non suspendu), débite l'acheteur, crédite l'artiste (pièces gagnées), `recordAppCommission` pour la part Afrolook, parrainages comme pour les cadeaux, écriture de `MusicLibrary`. Idempotent (id du document). Sur iPhone : seules des pièces achetées via l'App Store servent à payer (déjà le cas).

## 4. Écrans

Page « Musique » (menu principal et accès depuis le fil), thèmes clair et sombre (`AppColors.of(context)`), lecteur réduit persistant en bas :
1. **Pour toi** : classement pays → abonnements → reste du monde (mélangé) ;
2. **Gratuites** : les 17 musiques Afrolook + sons gratuits d'artistes ;
3. **Artistes** : titres validés, filtre genre/pays ;
4. **Ma bibliothèque** : achetés, téléchargés, récents ;
5. **Favoris** : cœur sur n'importe quel titre (gratuit ou acheté).
Page d'un titre : extrait de 30 s (déjà fait), prix d'utilisation et de vente, **Acheter**, **Créer un post**, posts faits avec ce son (5 par 5, déjà fait), **Signaler**.

## 5. Lecture hors application et téléchargement « façon YouTube »

Décision : un titre payant n'est **jamais** téléchargeable en fichier libre. « Télécharger » veut dire : disponible hors ligne **dans Afrolook**, invisible ailleurs, comme sur YouTube.

**Lecture en arrière-plan** : `audio_service` + `just_audio` (service audio Android avec notification pause/suivant/pochette, `UIBackgroundModes: audio` et session audio sur iPhone, commandes sur l'écran verrouillé). Nécessite une nouvelle version des stores (paquets natifs, pas de simple mise à jour Shorebird).

**Téléchargement protégé** :
1. Le téléphone demande une licence à `musicLicense({soundId, deviceId, attestation})`. Le serveur vérifie : achat présent, compte valide, titre non suspendu, appareil authentique (Play Integrity sur Android, App Attest sur iPhone), moins de 3 appareils.
2. Le serveur envoie le titre **chiffré** (AES-256-GCM par blocs, clé aléatoire propre au compte, à l'appareil et au titre) avec une marque sonore invisible propre à l'acheteur. La clé est rangée dans le coffre du téléphone (Keystore Android / Keychain iOS), jamais à côté du fichier.
3. Le fichier est écrit dans le dossier **privé** de l'application (Android : stockage interne de l'appli, hors MediaStore ; iPhone : Application Support, exclu des sauvegardes iCloud), avec une extension sans rapport avec l'audio. Il n'apparaît ni dans les fichiers, ni dans la galerie, ni dans les récents, ni dans les sauvegardes.
4. La lecture déchiffre en mémoire (source audio personnalisée) : aucun fichier en clair n'existe sur le téléphone. Android : la lecture est marquée non capturable par les autres applications (`ALLOW_CAPTURE_BY_NONE`).
5. Licence de 30 jours : renouvelée automatiquement en ligne. Achat annulé, compte suspendu ou titre retiré = licence refusée, fichier effacé à la prochaine ouverture. Téléphone vendu ou perdu : l'appareil se retire depuis le compte.
6. Écoute en ligne : liens signés de 5 minutes, par morceaux (Range), jamais de lien permanent.

**Protections supplémentaires** : limite de téléchargements par jour ; détection d'un appareil modifié (root, jailbreak) avant licence ; marque sonore invisible par acheteur pour retrouver l'origine d'une fuite ; **crédit automatique** « Musique : titre, artiste » (avec lien vers la page du titre) sur chaque post fait avec un son, pour que l'artiste soit toujours cité ; procédure de plainte et retrait immédiat.

**Limite assumée** : aucun système n'empêche d'enregistrer le son avec un autre appareil (micro). Le but est de rendre la copie pénible, de la tracer et de la retirer vite. Un son utilisé dans une vidéo publiée est mélangé dans la vidéo : c'est visible de tous comme n'importe quelle vidéo, d'où le crédit automatique.

## 6. Du fil à la vidéo

Déjà en place : carte musique dans le fil (lecture immédiate, bouton « Créer un post avec ce son »), modèles du Studio avec le son déjà choisi, annonce du prix et du solde avant, rien débité si le montage échoue, lien du post au son vérifié par le serveur.
**Fait (phase 5)** : « 🎥 Ma vidéo avec ce son » — chemin direct, sans modèle ni habillage (`kPlainTemplate`, absent de la galerie) : la personne choisit sa vidéo (ou sa photo) et la musique est ajoutée. **Le son d'origine de la vidéo est coupé par défaut** (seule la musique est jouée, vérifié côté serveur : `keepAudio` faux = aucune piste d'origine) ; un interrupteur « Garder le son de ma vidéo » permet de le mélanger. Accès : menu d'un titre de la page Musique, page du titre, carte du fil (icône caméra), et bouton « 🎬 Ma vidéo » du bandeau de la galerie des modèles. Le prix d'un son payant est annoncé avant (solde, part de l'artiste) et débité seulement si le montage réussit. Le résultat s'enregistre dans la galerie (album Afrolook) ou se publie. « Télécharger » et « Écouter hors de l'application » : faits en phase 3 (téléchargement protégé dans Afrolook ; lecture en arrière-plan).

## 7. Pays, abonnements, facturation

**Fait (phase 4)** : le champ `availableCountries` d'un titre suit la grille des posts, **appliquée par le serveur** : Gratuit 1 pays, Premium 20, Gold et administrateur tous (« ALL »). Les pays en plus **ne coûtent pas de pièces** (comme les posts). Un gratuit qui demande « tous » reçoit son pays ; des codes invalides sont ignorés ; sans choix valide, le pays du profil. L'artiste choisit les pays au dépôt (carte « Pays où ton titre est proposé ») et peut les changer plus tard depuis « Mes sons » (fonction `artistSoundCountries`). Un titre n'est proposé qu'aux personnes de ces pays (page Musique, carte du fil, choix de musique du Studio) ; ceux visés pour le pays de la personne passent devant. Ne sont pas filtrés : son propre titre, les titres de sa bibliothèque, un titre ouvert par lien. Les anciens titres (sans liste) restent pour tous. Le filtre se fait dans l'application sur les 150 titres les plus récents ; au-delà de ~500 titres, passer à une requête `array-contains-any` avec un index. Gold et Premium : écoute libre inchangée, les titres payants restent payants ; Gold ne voit aucune pub.

Ancienne version du plan : même grille que les posts : Gratuit 1 pays, Premium jusqu'à 20 pays, Gold tous les pays (règle déjà utilisée dans l'onglet Audio). Décision à prendre : les pays en plus coûtent-ils des pièces ? Classement du flux : pays de la personne, puis abonnements, puis le reste mélangé. Gold et Premium : à décider (écoute gratuite de tout ou seulement sans pub).

## 8. Publicité

**Fait** (tous passent par `AdSlot` / `AdGate` : AdMob d'abord, pub Afrolook en repli, rien si aucune pub, jamais pour Gold, nouveaux comptes épargnés) :
- **Pub native** tous les 6 titres des listes et **bannière** sous la liste (écran d'au moins 700 px) : emplacements AdMob **dédiés à la page Musique** (`musicNative`, `musicBanner`). Tant qu'aucun identifiant dédié n'est saisi dans `AppConfig/ads` → `units.<android|ios>.musicBanner` / `musicNative`, ce sont les emplacements habituels (bannière, natif) qui servent ; une fois créés dans AdMob et saisis, la console AdMob donne le revenu de la page Musique à part. Interrupteurs : `musicBanner`, `musicNative`.
- **Revenu estimé** : les événements « paid » d'AdMob de ces deux emplacements sont envoyés par groupes à `musicAdPaid` (50 par appel, 300 par personne et par jour) et cumulés par jour dans `MusicAdStats/{aaaammjj}` (`impr_banner`, `impr_native`, `micros_<DEVISE>_<emplacement>` = millionièmes). Lisible par l'administrateur seulement, **indicatif** : le chiffre officiel reste celui de la console AdMob.
- **Pub plein écran entre deux écoutes** (`MusicAds.beforeTrack`) : seulement au lancement d'un titre choisi par la personne (jamais pendant l'écoute), tous les 5 titres (`musicInterstitialEvery`), 3 par jour au plus (`musicInterstitialMaxPerDay`), mêmes écarts minimum et délai de début de session que dans le fil. Interrupteur `musicInterstitial`.
- **Titre payant écouté en entier contre une pub récompensée** (`musicAdListen`) : bouton « Écouter en entier (une pub) » (menu d'un titre, page du titre) pour un titre payant non acheté. La pub est comptée par le serveur (même réserve `AdRewards` que la page Récompenses et les Contes, avec la vérification AdMob quand elle est active) ; elle ouvre **une seule** écoute complète en ligne (valable 30 minutes pour la demander, lien de 10 minutes), 5 par jour au plus. Elle n'ouvre ni le téléchargement hors ligne, ni la bibliothèque : pour garder le titre il faut l'acheter. Interrupteur `musicRewarded`.

**Pas fait** : un écran d'administration pour lire `MusicAdStats` (lecture dans la console Firebase pour l'instant).

Plan d'origine :
AdMob d'abord, pub Afrolook en repli (règle appliquée partout). Emplacements : native entre titres (tous les 6), bannière sous le lecteur, interstitiel rare entre deux écoutes (jamais pendant un titre, au plus un par 5 titres et 5 minutes), pub récompensée pour écouter un titre payant en entier une fois. Gold sans pub ; nouveaux comptes épargnés (règles `AdGate`).

## 9. Sécurité : analyse

| Risque | Mesure | État |
|---|---|---|
| Voler le fichier d'un artiste | Original dans `artist_sound_uploads/{uid}/` : aucune lecture client (règles Storage), ni pour l'artiste ; le public n'a que l'extrait ; admin = lien signé 15 min | fait, testé |
| Se faire passer pour l'artiste en reliant le fichier d'un autre | La règle Firestore exige `audioPath` dans le dossier du déposant ; l'analyse refuse tout autre chemin | fait, testé |
| Redéposer le même fichier | SHA-256 : refus automatique citant l'original | fait, testé |
| Redéposer le même morceau retouché (MP3, recadré, volume) | Empreinte audio : alerte admin avec le titre d'origine et l'écart ; testé : écart 9 à 12 % pour des copies, 47 à 49 % pour des morceaux sans rapport | fait, testé |
| Morceau accéléré, transposé, remixé | Non détecté : écoute admin + signalements | limite assumée |
| S'attribuer des gains ou des utilisations | Compteurs et pièces écrits seulement par le serveur ; règle de création impose compteurs à 0 et `pending_review` | fait, testé |
| Faire passer son post pour « fait avec ce son » | `artistSoundId` interdit en écriture client ; lien par `artistSoundLinkPost` vérifiant le montage payé et le propriétaire du post | fait, testé |
| Payer deux fois / jamais | Un document `ArtistSoundUses/{uid}_{jobId}` par montage ; débit seulement après montage réussi | fait, testé |
| Supprimer le son d'un autre | `artistSoundDelete` : propriétaire ou admin ; l'artiste retape le titre exact | fait, testé |
| Abus de signalements | Un par personne et par son ; 3 = suspension (réversible par l'admin) ; l'artiste ne peut pas signaler son propre son | fait, testé |
| Fuite d'un titre acheté | Téléchargement caché et chiffré dans l'application (§ 5), licence de 30 jours, 3 appareils, 20 téléchargements/jour, liens d'écoute de 10 minutes | fait (phases 2–3) ; reste à faire : appareil authentique (Play Integrity / App Attest) et marque sonore invisible par acheteur |
| Copie par enregistrement d'écran/micro | Aucune protection technique complète possible : dissuader, retrouver, retirer | limite assumée |
| Droits d'auteur : artiste qui dépose un titre qu'il ne possède pas | Case de certification obligatoire, sanction du compte, retrait immédiat sur plainte, preuve demandée au vrai auteur | fait (certification), procédure à documenter |
| Mineurs, contenu choquant | Écoute avant validation ; motif « choquant » dans le signalement | fait |

Points d'attention : le comparateur d'empreintes parcourt tous les sons (limite ~3000) ; au-delà, passer à un index (hachage par segments). L'analyse tourne en tâche serveur (1 Gio, 3 instances maximum).

## 9 bis. État des phases

- **Phase 1 (page Musique, favoris, crédit sur les posts)** : faite.
- **Phase 2 (prix par titre, achat, bibliothèque, écoute complète)** : faite et testée sur le serveur.
  - Prix d'utilisation 2–20 pièces et prix de vente 50–500 pièces fixés par l'artiste (règles Firestore) ; l'artiste touche 60 %.
  - `musicBuy` (transaction unique, idempotente), `musicStreamUrl` (titre gratuit, acheté ou à soi ; 300 écoutes complètes par jour).
  - Lien d'écoute : copie temporaire du fichier dans `artist_sound_tmp/` (dossier fermé aux téléphones) avec un jeton, supprimée par la tâche `cleanupTempListen` toutes les 10 minutes. Les liens signés Google ne sont pas utilisés : le compte de service du projet n'a pas le droit de signer (non modifié).
  - Le lien d'écoute de l'administrateur (avant validation) utilise le même mécanisme : il ne fonctionnait pas avant cette correction.
- **Phase 3 (lecture en arrière-plan + téléchargement protégé)** : faite côté serveur (testé en réel) et côté application (analysée et testée en logique ; **pas encore essayée sur un téléphone**, il faut un nouveau build Android/iOS).
  - Lecture en arrière-plan : `just_audio` + `just_audio_background` (un seul lecteur dans l'application). Android : service média + notification avec pochette et commandes, activité `AudioServiceFragmentActivity`, permissions `FOREGROUND_SERVICE(_MEDIA_PLAYBACK)`. iPhone : `UIBackgroundModes: audio`. La musique continue quand on quitte la page Musique.
  - `musicLicense({soundId, deviceId, renew?})` : titre gratuit, acheté ou à soi ; titre retiré/suspendu = `RETIRE` ; **3 appareils maximum** par titre (`APPAREILS`), **20 téléchargements par jour** (`LIMITE_JOUR`, un renouvellement n'est pas compté), licence de **30 jours**, clé AES-256 aléatoire propre à la personne, au titre et à l'appareil. Collection `MusicLicenses` fermée à tous les téléphones (elle contient les clés).
  - Application (`lib/services/offline_music_service.dart`) : téléchargement par le lien d'écoute temporaire, chiffrement **AES-256-GCM** (authentifié : un fichier modifié est refusé), rangé dans `<Application Support>/afrolook_m/<nom sans rapport>.bin`, clé dans Keystore/Keychain (iPhone : « cet appareil seulement »), jamais dans la galerie, les fichiers ni les récents ; exclu des sauvegardes Android (`backup_rules.xml`, `data_extraction_rules.xml`). Lecture : déchiffrement en mémoire (source audio personnalisée), renouvellement automatique dans les 7 derniers jours de licence, effacement si le droit sur le titre a disparu, message clair si la licence a expiré hors ligne.
  - Interface : menu « Télécharger (écouter sans internet) » / « Retirer du téléphone » dans la page Musique, bouton sur la page du titre, pastille « téléchargé ».
  - **Pas fait** (à décider) : attestation d'appareil (Play Integrity / App Attest), marque sonore invisible par acheteur, blocage de la capture audio par d'autres applications Android (`allowAudioPlaybackCapture="false"` couperait aussi le son des enregistrements d'écran de toute l'application, donc non activé), détection root/jailbreak.
- **Phase 4 (pays, abonnements, pubs)** : faite (voir § 7 et § 8). Serveur testé en réel : gratuit 1 pays, Premium 20, Gold tous, titre d'un autre refusé, codes invalides ignorés, écriture directe du champ refusée par les règles. Côté application : analysée, pas essayée sur un téléphone.
- **Phase 5 (« Ma vidéo avec ce son », son d'origine coupé, export)** : faite côté application (analysée et testée par widget, pas essayée sur un téléphone) ; le montage serveur existait déjà et n'a pas changé.

## 9 ter. Lecture rapide et CDN (16 octobre 2026)
- **Cause probable du « play qui tourne sans rien jouer »** : `just_audio_background` remplace la plateforme audio avant de finir son initialisation ; si celle-ci échoue ou traîne (service Android absent, build sans les éléments natifs de la phase 3…), le lecteur reste bloqué pour toujours. Corrigé : `main.dart` garde la plateforme d'origine, limite l'initialisation à 6 s et la remet en place en cas d'échec (la musique joue alors normalement, sans notification). Autres garde-fous : chaque étape du lancement a un délai maximum (3 s, 12 s, 8 s pour le lien du titre complet), un lancement plus récent annule le précédent, la pub plein écran ne bloque jamais la lecture (erreurs ignorées, 45 s maximum), le sablier de la page Musique s'arrête toujours.
- **Départ instantané** : `MusicCache` garde les extraits et musiques gratuites sur le disque (80 fichiers au plus, extraits de moins de 3 Mo) ; la page Musique précharge les 8 premiers extraits et 4 musiques gratuites dès qu'elle s'affiche, la 2e écoute d'un titre est donc instantanée.
- **CDN** (`lib/utils/media_cdn.dart`) : extraits, pochettes, photos d'artistes et musiques gratuites passent par `cdn.afrolookmedia.com/media/…` (même mécanisme que le reste des médias, interrupteur `cdn_active` de Remote Config) ; si le CDN ne répond pas, retour automatique sur Firebase Storage. **Les titres complets (liens d'écoute temporaires) ne passent pas par le CDN** : leur lien meurt après 10 minutes et un cache public les garderait en ligne. Constat du 16 octobre : le CDN répond bien (lecture par morceaux acceptée) mais `cf-cache-status: DYNAMIC`, c'est-à-dire qu'il ne met rien en cache chez Cloudflare ; pour le rendre vraiment plus rapide, ajouter dans Cloudflare une règle de cache sur `/media/*` (« Cache Everything », durée longue).
- **Jetons des musiques gratuites** : 14 des 17 fichiers `studio_music/*.m4a` n'avaient pas de jeton de téléchargement (l'application n'obtenait pas leur lien) : ajoutés, avec un en-tête de cache d'un an.
- **Réseau local** : le lecteur relaie la lecture hors ligne chiffrée par un petit serveur local de l'appareil ; Android bloquait ce trafic (Android 9+) et iPhone aussi (ATS) : réglages `network_security_config.xml` (127.0.0.1 et localhost seulement) et `NSAllowsLocalNetworking`.
- **Menu** : entrée « Musique » dans le menu latéral (et dans la barre latérale large).
- **Musique dans le fil** (`lib/pages/studio/feed_sound_card.dart`) : le bandeau figé sous les chroniques est supprimé. Trois présentations alternent : **l'affiche** (pochette en plein cadre 4:5, voile dégradé, grand bouton de lecture avec cercle d'avancement, titre, genre · durée · nombre de posts, boutons « Créer un post », « Ma vidéo avec ce son », « Toute la musique »), **« Musiques du moment »** (rangée de pochettes verticales avec lecture sur chaque pochette) et **« Top titres »** (liste numérotée façon lecteur : pochette, titre, genre · durée, prix, lecture). Elles reviennent entre le 5ᵉ et le 9ᵉ post puis tous les 11 à 19 posts, à des endroits qui changent à chaque ouverture (graine par session, `_musicPositions` dans `HomeConstPost.dart`) ; chaque carte propose d'autres titres que la précédente, filtrés par pays. Les extraits sont préchargés.

## 9 quater. Refonte « disque » : file d'attente, lecteur flottant, fin d'extrait (17 octobre 2026)

Maquettes validées par le propriétaire (page Musique, fiche du titre, feuille de fin d'extrait, lecteur flottant, widgets du fil), dans les écrans réels de l'application, en clair et en sombre.

- **Prix en pièces, deux actions distinctes** : « Créer un post · 🪙 5 » (prix d'utilisation, 2 à 20 pièces, 60 % à l'artiste) et « Acheter · 🪙 100 » (prix de vente du titre complet, 50 à 500 pièces, 60 % à l'artiste). Gratuit : rien à payer.
- `lib/services/music_queue.dart` : `MusicTrack` (titre gratuit, son d'artiste, titre de la bibliothèque), `MusicQueue` (file, suivant, précédent, aléatoire sans répéter les 3 derniers titres, fin d'extrait, préchargement des 2 titres suivants, pause devant une vidéo). Un seul lecteur reste `SoundPreview` ; il annonce la fin d'un titre (`completed`).
- `lib/widgets/music/` : `vinyl.dart` (disque qui tourne, bras de lecture, anneau de progression), `music_overlay.dart` (lecteur flottant en capsule au-dessus de toutes les pages, via `MaterialApp.builder`, glissable verticalement, masqué quand le clavier est ouvert), `preview_end_sheet.dart` (feuille « Tu aimes ce titre ? » : acheter, écouter en entier avec une pub, créer un post, plus tard ; « Recharger mes pièces » si le solde ne suffit pas ; soutien de l'artiste).
- **Visibilité** : le lecteur flottant est visible sur le fil, le détail d'un post sans vidéo, Quiz & Étude et toutes les pages sans média animé. Il est masqué, et la musique mise en pause puis reprise à la fermeture, sur les pages à vidéo, live, chronique, éditeur et Studio (`MusicSuspendMixin`, `HideMusicOverlay`) ; la page Musique le masque dans l'onglet « Pour toi » (la carte « en lecture » le remplace). Quand le son des vidéos du fil est ouvert (`SoundProvider`), la musique se met en pause.
- **Page Musique** : carte « en lecture » avec disque, deux boutons (Post, Acheter), nouveautés en rangée, lignes avec bouton « Post » et lecture. **Fiche du titre** : disque, barre avec zone verrouillée, deux actions. **Fil** : affiche, rangée « Sons du moment », « Top 5 du pays », crédit « ♪ titre » avec le bouton « Utiliser · 🪙 5 ».
- **Site afrolookmedia.com** : titre et texte d'accueil parlent de musique ; les vrais écrans (HTML/CSS, `site/src/mock.mjs`) sont dans la section Musique de l'accueil et sur la page Musique.
- Tests : `test/music_player_test.dart` (prix, titre suivant, feuille de fin d'extrait, disque), `test/feed_sound_card_test.dart`.

## 10. Feuille de route

1. Page Musique + favoris gratuits (1 semaine).
2. Prix de vente, achat, bibliothèque (1 à 2 semaines).
3. Lecture en arrière-plan + hors ligne chiffré (1 à 2 semaines, nouvelle version des stores).
4. Pays, abonnements, publicité (1 semaine).
5. Vidéo avec musique seule + export (1 semaine).
Estimations de travail, à confirmer.

## 11. Décisions prises

1. Artiste : 60 % de chaque vente et de chaque utilisation.
2. Prix : vente de 50 à 500 pièces, utilisation de 2 à 20 pièces.
3. Titres payants : lecture et téléchargement dans l'application seulement (voir § 5), jamais en fichier libre.
4. Gold et Premium : sans pub ; un titre payant reste payant (proposition de l'équipe technique : l'artiste est toujours payé).
5. Validation : l'équipe seule au début.

Reste ouvert : les pays supplémentaires coûtent-ils des pièces (même grille que les posts : gratuit 1 pays, Premium 20, Gold tous) ?

## 9 quinquies. Playlists, écoutes et gains par titre

**Playlists** (onglet « Playlists » de la page Musique, « Mes playlists ajoutées » dans Ma bibliothèque, « Ajouter à une playlist » dans le menu ⋮ d'un titre) :
- Tout le monde voit une playlist et son contenu. Elle est **gratuite** ou **payante** (de 20 à 500 pièces, le créateur touche 60 %).
- Ajouter une playlist à sa bibliothèque (gratuit ou payant) permet de la lancer en entier, même en quittant l'application (lecture en arrière-plan). Sans ajout : un titre à la fois.
- Les titres payants d'artistes sont permis mais **signalés** (pastille « Titre payant », carte d'avertissement sur la page et dans l'éditeur, rappel dans la confirmation d'achat). Acheter la playlist ne les débloque pas : sans achat de chaque titre, seul l'extrait de 30 s est lu, que le créateur de la playlist l'ait acheté ou non. À la fin d'un extrait dans une playlist : la voix annonce le prix, puis le titre suivant démarre.
- Transactions nommées : « Achat de la playlist « X » — N pièces » / « Vente de ta playlist « X » — N pièces reçues ».
- Le créateur voit sur sa playlist : ajouts, écoutes, pièces gagnées.

**Écoutes (streams)** : une écoute = 10 secondes de lecture (ou le titre / l'extrait écouté en entier s'il est plus court), comptée par le serveur (`musicStream`) : 1 par personne, par titre et par tranche de 10 min, 600 par jour. Les écoutes de l'artiste sur son propre titre comptent aussi (comme sur les plateformes). Les musiques gratuites d'Afrolook ont leur compteur (`MusicStudioStats`). Le nombre d'écoutes est affiché en direct partout où un titre apparaît (`StreamsText`) : lignes, fiche du titre, lecteur flottant, cartes du fil, crédit sous les posts, playlists, espace artiste, choix de musique du Studio.

**Extrait gratuit** : sa durée dépend de celle du titre : un quart du titre, entre 8 et 30 secondes (30 s dès 2 minutes). Elle est enregistrée dans le son (`previewSec`) ; les anciens sons courts ont été refaits.

**Pièces gagnées par titre** (fiche du titre pour l'artiste, « Mes sons ») : ventes du titre (`saleEarnings`), utilisations dans des posts (`useEarnings`), total. Les écoutes ne rapportent pas de pièces.

Serveur : `functions/src/studio/musicPlaylists.ts` (`playlistSave`, `playlistDelete`, `playlistAdd`, `musicStream`). Client : `lib/services/music_playlists.dart`, `lib/pages/music/playlists_pages.dart`.
