# Taille de l'application : causes et plan de réduction (09/11/2026)

Constat du propriétaire : plus de **300 Mo sur iPhone** et plus de **150 Mo sur Android** après traitement. Ce document donne les causes mesurées, ce qui est déjà fait et ce qui reste à décider.

## 1. Ce qui a été mesuré (Android)

Source : le bundle de production `build/app/outputs/bundle/release/app-release.aab` (252 Mo de fichier, 647 Mo décompressés, 240 Mo compressés). Un téléphone ne télécharge que **la base + UNE architecture** (arm64 en général) : le fichier de 252 Mo contient aussi l'autre architecture (armeabi-v7a), les symboles de débogage (25 Mo) et la table de correspondance R8 (17 Mo), qui ne partent jamais chez les utilisateurs.

| Poste | Décompressé | Compressé | Remarque |
|---|---|---|---|
| Bibliothèques natives arm64 | 144 Mo | 67 Mo | seulement pour les téléphones 64 bits |
| Bibliothèques natives armeabi-v7a | 105 Mo | 57 Mo | seulement pour les téléphones 32 bits |
| Ressources « assets » natives Android | 62 Mo | 51 Mo | modèles d'IA, OCR, régie |
| Code Java / Kotlin (dex) | 53 Mo | 20 Mo | Appodeal et ses réseaux, Firebase, Agora, AdMob |
| Ressources Flutter (`flutter_assets`) | 26 Mo | 2 Mo | dont un fichier de 25,7 Mo (voir ci-dessous) |

Bibliothèques natives les plus lourdes (deux architectures additionnées) :

| Bibliothèque | Mo | À quoi elle sert |
|---|---|---|
| `libapp.so` (le code Dart de l'application) | 58,0 | l'application elle-même |
| `libagora-rtc-sdk.so` | 46,9 | lives (Agora) : indispensable |
| `libflutter.so` | 22,6 | moteur Flutter : indispensable |
| `libmlkit_google_ocr_pipeline.so` | 17,0 | lecture de texte dans les vidéos (détection de marques d'autres réseaux) |
| `libmediapipe_tasks_vision_jni.so` | 13,7 | filtres de visage (Android) |
| 9 extensions Agora **inutilisées** | environ 40 | synchronisation labiale (13), audio spatial (8,5), fond virtuel (4,4), capture de visage (4,2), beauté audio (3,6), inspection de contenu (2,9), AV1 (2,3 + 1,5), analyse de qualité (1,2) |
| `libtensorflowlite_jni.so` + GPU | 10,8 | contrôle de contenu explicite (modèle de 24 Mo) |

Ressources les plus lourdes :

| Fichier | Mo | Plateformes | Remarque |
|---|---|---|---|
| `csc_picker_plus/.../countries.json` | **25,7** | Android et iPhone | liste pays, régions et villes du monde, pour 3 écrans (inscription, mise à jour du profil, ajout de produit) |
| `nsfw_mobilenet_v2_140_224.tflite` | **23,3** | Android et iPhone | contrôle de contenu explicite fait sur le téléphone |
| `selfie_multiclass_256x256.tflite` | 15,6 | Android seulement | segmentation du moteur de filtres de visage |
| `face_landmarker.task` | 3,6 | Android seulement | suivi du visage |
| `intro_video.mp4` | 1,7 | les deux | |
| Audience Network (Meta) `classes2.dex` | 5,0 | Android | un des réseaux de la régie Appodeal |

## 2. Causes principales

1. **Agora** : le SDK complet (46,9 Mo) plus **neuf extensions que l'application n'utilise pas**. L'application emploie Agora seulement pour le live (audio, vidéo, partage d'écran et la beauté vidéo de base `setBeautyEffectOptions`, qui dépend de `libagora_clear_vision_extension.so`).
2. **Appodeal et ses réseaux publicitaires** : 13 adaptateurs côté Android (AdMob, AppLovin, Bidon, BidMachine, DT Exchange, InMobi, Unity, Meta, PubMatic, MobileFuse, Ogury, TaurusX, Verve) et 6 côté iPhone. C'est la majeure partie des 53 Mo de code Java / Kotlin.
3. **Deux gros fichiers de données** livrés à tout le monde : la liste mondiale des villes (25,7 Mo) et le modèle de contrôle de contenu (23,3 Mo).
4. **Moteur de filtres de visage Android** : 19 Mo de modèles + 14 Mo de bibliothèques MediaPipe, même pour ceux qui n'utilisent jamais les filtres.
5. **Lecture de texte (OCR)** embarquée (17 Mo de bibliothèques + modèles) au lieu de la version fournie par Google Play.
6. **Code Dart** : 27 Mo (arm64) ; les noms de symboles ne sont pas réduits (pas de `--obfuscate`).
7. **iPhone (300 Mo)** : pas mesurable depuis un PC Windows. Les suspects sont les mêmes (Agora et ses extensions, Appodeal et 6 adaptateurs, OCR et TensorFlow Lite, 38 Mo de ressources partagées non compressées une fois installées, `use_frameworks!` qui duplique des bibliothèques Swift). La mesure exacte viendra du prochain build Codemagic (voir 4).

## 2 bis. Ce qui a été mesuré sur iPhone (fichier `afrotok.ipa` de Codemagic, 09/11/2026)

Le fichier fait **168 Mo**, mais 41 Mo (dossier `Symbols`, 196 Mo décompressés) servent seulement à l'envoi à Apple et **ne sont jamais installés** : l'application elle-même pèse **environ 126 Mo compressés, 299 Mo décompressés** (c'est ce chiffre de 299 Mo qui est affiché une fois installée, avant l'allègement d'Apple par modèle d'iPhone). Elle était à 376 Mo sur TestFlight avant l'allègement du 07/11.

| Poste | Mo décompressés | Détail |
|---|---|---|
| **Moteur Flutter + code Dart + ressources** (`App.framework`, `Flutter.framework`) | 101 | code Dart 28,6 ; **liste mondiale des villes 25,7** ; **modèle de contrôle de contenu 23,3** ; polices, sons, images, vidéo d'introduction environ 13 ; moteur 10 |
| **Programme principal** (`Runner`) | 67 | code lié en dur : Firebase, AdMob, Appodeal et ses réseaux, ML Kit (lecture de texte), TensorFlow Lite… (le détail vient de l'analyse Codemagic) |
| **Agora** (lives) | 56 | SDK 20 + moteur vidéo 6 + **extensions inutilisées 20** (synchronisation labiale 6,4 ; audio spatial 3,9 ; capture de visage 2,1 ; fond virtuel 2,1 ; beauté audio 1,4 ; inspection 1,3 ; AV1 1,0 ; analyse de qualité 0,9) |
| **Firebase et Google** (gRPC, Firestore, abseil, OpenSSL…) | 31 | gRPC 12,3 ; Firestore 4,7 |
| **Réseaux publicitaires en bibliothèques** | 19 | Meta (Audience Network) 6,7 ; InMobi 6,2 ; AppLovin 5,9 |
| Autres (66 bibliothèques) | 19 | dont `rive_common` 3,0 (tiré par le paquet `awesome_dialog`), navigateur intégré 3,2 (deux paquets : `flutter_inappwebview` tiré par `cinetpay`, et `webview_flutter`) |
| Web, ML Kit (ressources), signatures, icônes | environ 6 | |

Constats : **49 Mo de données** (villes + contrôle de contenu) sont embarqués dans le code Dart des deux plateformes ; les **extensions Agora inutilisées** pèsent 20 Mo sur iPhone comme sur Android ; deux paquets servent seulement à des écrans secondaires et embarquent chacun une bibliothèque (voir 4, lignes 9 et 10).

## 3. Déjà fait (09/11/2026)

- **Android : 9 extensions Agora inutilisées retirées** (`android/app/build.gradle`, bloc `packagingOptions`). Gain **calculé sur le bundle de production** : **arm64 : 23,7 Mo installés, 14,9 Mo téléchargés** en moins ; **armeabi-v7a (32 bits) : 19,1 Mo installés, 13,7 Mo téléchargés** en moins. La configuration Gradle a été vérifiée (`./gradlew :app:help`) ; la fabrication complète d'un nouveau bundle reste à faire par toi. Elle garde la beauté vidéo de base du live. À essayer sur téléphone : un live avec la beauté activée.
- **Android : 5 réseaux publicitaires Appodeal retirés** (PubMatic, MobileFuse, Ogury, TaurusX, Verve) pour avoir **les mêmes réseaux que sur iPhone** (AppLovin, BidMachine, DT Exchange, InMobi, Meta, Unity) plus AdMob et son lien Bidon. Gain estimé : 8 à 12 Mo décompressés ; à mesurer au prochain build. À faire dans le tableau de bord Appodeal (facultatif) : désactiver ces réseaux.
- **Villes (les deux plateformes) : FAIT.** `csc_picker_plus` (liste mondiale pays, régions et villes de **25,7 Mo**) est retiré. Un sélecteur léger (`lib/widgets/location_picker.dart`, liste de pays de 6 Ko aux **mêmes noms** que l'ancien paquet, donc profils existants compatibles) le remplace sur les 3 écrans : inscription, mise à jour du profil, ajout de produit (celui-ci n'utilisait plus le sélecteur). Le pays se choisit dans une liste avec recherche ; **la région et la ville se saisissent maintenant librement** (facultatives).
- **`awesome_dialog` retiré : FAIT** (et avec lui `rive` : 3 Mo sur iPhone). 7 fenêtres de confirmation du code SMS utilisent `lib/widgets/status_dialog.dart`.
- **iPhone : extensions Agora inutilisées retirées (Podfile) : FAIT, À CONTRÔLER sur Codemagic.** 9 extensions (synchronisation labiale, audio spatial, capture de visage, fond virtuel, beauté audio, inspection de contenu, AV1 ×2, analyse de qualité), environ 20 Mo. Le bloc est prudent (liens « faibles », rien n'est modifié si un lien fort subsiste, une erreur n'arrête pas le build) mais **n'a pas pu être testé ici** : au prochain build, vérifier dans le journal la ligne « [allègement Agora] … », la taille du `.ipa` et qu'un live démarre sur iPhone. S'il plante au lancement : supprimer le bloc.
- **Reste à décider (rien appliqué) :** modèle de contrôle de contenu (23,3 Mo : quantifier ou télécharger, il faut un lieu d'hébergement), réseaux publicitaires restants (revenus par réseau nécessaires), `cinetpay` (la page « Premium entreprise » l'utilise encore).
- **Codemagic** : le détail de la taille de l'application iPhone (`--analyze-size`, déjà actif) est maintenant publié avec le build (`*code-size-analysis*.json`). Envoie-le, ou envoie le fichier `.ipa`, et j'en tire la liste exacte.
- **Garde automatique** (`test/platform_assets_test.dart`) : les modèles du moteur de visage restent dans le dossier d'Android et jamais dans les ressources partagées avec l'iPhone ; le dossier partagé a un budget de 45 Mo.

## 4. À décider (par ordre de gain)

| # | Action | Gain estimé | Risque / coût | Décision à prendre |
|---|---|---|---|---|
| 1 | Remplacer la liste mondiale des villes (25,7 Mo) par une liste légère (pays + régions + villes des pays africains, ou villes saisies à la main) | **25 Mo installés** (environ 3 Mo téléchargés), les deux plateformes | 3 écrans à refaire, donnée à fournir | Quels pays et niveaux de détail (pays seulement, ou région et ville) ? |
| 2 | Réduire le modèle de contrôle de contenu : version quantifiée (environ 6 Mo) ou téléchargement au premier usage | **17 à 23 Mo**, les deux plateformes | précision à vérifier ; hébergement du modèle | Quantifier ou télécharger ? |
| 3 | Réduire les réseaux publicitaires Appodeal (garder ceux qui rapportent) | **10 à 25 Mo** de code Java, et autant côté iPhone | baisse possible des revenus pub | Données de remplissage et de revenu par réseau dans Appodeal |
| 4 | Filtres de visage Android : télécharger les modèles (19 Mo) au premier usage | **19 Mo** pour tous les autres | téléchargement à gérer, hors ligne | Oui ou non |
| 5 | Lecture de texte (OCR) : version Google Play (non embarquée) | environ **8 à 10 Mo** par architecture | dépend du paquet utilisé | À étudier |
| 6 | Build Android avec `--obfuscate --split-debug-info=…` | **3 à 6 Mo** | symboles à garder pour les rapports d'erreur | Changer la commande de build |
| 7 | iPhone : même retrait des extensions Agora (script de liaison faible dans le Podfile) | **10 à 15 Mo** | script Podfile à tester sur Codemagic | Après la mesure du build |
| 9 | Remplacer `awesome_dialog` (3 écrans de confirmation par code) par des fenêtres simples : il tire `rive` | **3 Mo** sur iPhone (`rive_common`), moins de code Android | 3 petits écrans, animation perdue | Oui ou non |
| 10 | `cinetpay` : la page d'abonnement « Premium entreprise » (`Subscription.dart`, appelée depuis l'ajout de produit et « Mon abonnement ») l'utilise ; il tire le navigateur intégré `flutter_inappwebview` | **2 à 4 Mo** | CinetPay est-il encore utilisé pour payer ? (le reste de l'appli est en pièces) | À trancher |
| 8 | Retirer les téléchargements 32 bits (armeabi-v7a) | 0 Mo pour l'utilisateur (il ne télécharge qu'une architecture), gain seulement sur le fichier envoyé | téléphones 32 bits non pris en charge : à éviter en Afrique | Non recommandé |

## 5. Gain total attendu

Sur iPhone, les actions 1 et 2 enlèvent à elles seules **49 Mo décompressés** (sur 299), l'action 7 environ 20 Mo, l'action 3 jusqu'à 19 Mo : on peut viser **moins de 220 Mo installés** (contre 299 aujourd'hui). Sur Android, les actions 1, 2, 4 et 5 enlèvent environ **60 à 70 Mo décompressés** et les actions 1 à 6 environ **20 à 30 Mo téléchargés** ; sur iPhone, les actions 1, 2, 3 et 7 pèsent le plus. L'objectif réaliste est de passer l'iPhone sous 250 Mo et l'Android sous 120 Mo ; la mesure exacte de l'iPhone décidera de la suite.
