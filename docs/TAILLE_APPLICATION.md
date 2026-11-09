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

## 3. Déjà fait (09/11/2026)

- **Android : 9 extensions Agora inutilisées retirées** (`android/app/build.gradle`, bloc `packagingOptions`). Gain **calculé sur le bundle de production** : **arm64 : 23,7 Mo installés, 14,9 Mo téléchargés** en moins ; **armeabi-v7a (32 bits) : 19,1 Mo installés, 13,7 Mo téléchargés** en moins. La configuration Gradle a été vérifiée (`./gradlew :app:help`) ; la fabrication complète d'un nouveau bundle reste à faire par toi. Elle garde la beauté vidéo de base du live. À essayer sur téléphone : un live avec la beauté activée.
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
| 8 | Retirer les téléchargements 32 bits (armeabi-v7a) | 0 Mo pour l'utilisateur (il ne télécharge qu'une architecture), gain seulement sur le fichier envoyé | téléphones 32 bits non pris en charge : à éviter en Afrique | Non recommandé |

## 5. Gain total attendu

Sur Android, les actions 1, 2, 4 et 5 enlèvent environ **60 à 70 Mo décompressés** et les actions 1 à 6 environ **20 à 30 Mo téléchargés** ; sur iPhone, les actions 1, 2, 3 et 7 pèsent le plus. L'objectif réaliste est de passer l'iPhone sous 250 Mo et l'Android sous 120 Mo ; la mesure exacte de l'iPhone décidera de la suite.
