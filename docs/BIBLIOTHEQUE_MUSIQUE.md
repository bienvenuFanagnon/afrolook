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
À ajouter : mode « vidéo avec musique seule » (le son d'origine est déjà coupé par défaut : option `keepAudio` désactivée) ; boutons « Télécharger » et « Écouter hors de l'application » sur la page du titre.

## 7. Pays, abonnements, facturation

Même grille que les posts : Gratuit 1 pays, Premium jusqu'à 20 pays, Gold tous les pays (règle déjà utilisée dans l'onglet Audio). Décision à prendre : les pays en plus coûtent-ils des pièces ? Classement du flux : pays de la personne, puis abonnements, puis le reste mélangé. Gold et Premium : à décider (écoute gratuite de tout ou seulement sans pub).

## 8. Publicité

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
| Fuite d'un titre acheté | Téléchargement caché et chiffré dans l'application (§ 5), licence de 30 jours, 3 appareils, appareil authentique exigé, marque sonore invisible par acheteur, liens signés de 5 minutes | à faire (phases 2–3) |
| Copie par enregistrement d'écran/micro | Aucune protection technique complète possible : dissuader, retrouver, retirer | limite assumée |
| Droits d'auteur : artiste qui dépose un titre qu'il ne possède pas | Case de certification obligatoire, sanction du compte, retrait immédiat sur plainte, preuve demandée au vrai auteur | fait (certification), procédure à documenter |
| Mineurs, contenu choquant | Écoute avant validation ; motif « choquant » dans le signalement | fait |

Points d'attention : le comparateur d'empreintes parcourt tous les sons (limite ~3000) ; au-delà, passer à un index (hachage par segments). L'analyse tourne en tâche serveur (1 Gio, 3 instances maximum).

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
