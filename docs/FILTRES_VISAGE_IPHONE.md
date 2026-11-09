# Filtres de visage sur iPhone : plan (09/11/2026)

Décision du propriétaire (09/11/2026) : les filtres de visage doivent exister aussi sur iPhone, comme sur CapCut et TikTok, **sans alourdir l'application** (chaque plateforme n'embarque que ce qui la concerne : voir `docs/TAILLE_APPLICATION.md` et `test/platform_assets_test.dart`).

## 1. Où nous en sommes

| | Android | iPhone |
|---|---|---|
| Moteur de visage | **maison** : CameraX + MediaPipe Face Landmarker (478 points) + OpenGL, environ 1 800 lignes (`android/app/src/main/kotlin/com/afrotok/afrotok/FaceEngine.kt`, `FaceChannel.kt`), pose le filtre et la beauté dans la vidéo au moment du tournage | **aucun** |
| Détection sur photo | ML Kit (module Google Play, non embarqué) | aucune |
| Passes serveur de secours | `/studio/beauty`, `/studio/face-overlay` (filtre posé après coup) | idem, mais sans point de visage à leur donner |
| Coupure | `FaceFilters.available` et `FaceEngine.enabled` valent `Platform.isAndroid` | idem : filtres désactivés |

CapCut et TikTok détectent le visage **sur le téléphone** (outils d'Apple ou modèles propres), dessinent le filtre avec la carte graphique (Metal) et exportent sur le téléphone. Le serveur ne suit rien.

## 2. Recommandation : trois phases, de la plus légère à la plus lourde

**Phase 1 : photos sur iPhone (petite, sûre).** Un petit module Swift d'une centaine de lignes, `afrolook/faces` côté iPhone, qui répond à la même demande de détection que sur Android en s'appuyant sur le framework **Vision** d'Apple (`VNDetectFaceLandmarksRequest`). Vision fait partie d'iOS : **0 Mo ajouté**, aucun pod. Le dessin du masque et la beauté sur photo restent faits comme sur Android (Dart et serveur).

**Phase 2 : vidéos sur iPhone (moyenne).** Pas de moteur OpenGL sur iPhone. La vidéo est filmée normalement ; après l'enregistrement, le téléphone repère le visage sur des images extraites (environ 10 par seconde, Vision), et envoie au serveur une **piste de positions** (quelques Ko). Le serveur pose le filtre dans la **même chaîne de rendu unique** que le reste du montage (l'interrupteur `studio_single_pass` existe déjà), en suivant la piste. Avantages : un seul code de rendu pour Android et iPhone, aucun poids en plus. Limite : l'effet n'est pas visible en direct pendant le tournage, seulement dans « Voir le rendu exact » et à la publication.

**Phase 3 : aperçu en direct sur iPhone (grosse, facultative).** Caméra AVFoundation + Metal, comme le moteur Android. À faire seulement si le résultat des phases 1 et 2 ne suffit pas.

## 3. Règles à respecter
- **Pas de dépendance lourde pour l'iPhone** : Vision est dans iOS ; rien dans le Podfile ; aucun modèle dans `assets/` (ils iraient aussi dans Android). Après chaque build iPhone, comparer la taille du `.ipa` à l'ancienne.
- **Android inchangé** : le moteur existant reste tel quel ; aucun code d'Android n'est livré à l'iPhone ni l'inverse.
- **Vie privée** : tout se fait sur le téléphone. La phase 2 envoie des **coordonnées** de points du visage : à déclarer dans la fiche de confidentialité d'Apple et de Google (donnée de visage ou « autre donnée ») et à garder seulement le temps du rendu. **Point à décider avant la phase 2.**
- **Essai** : aucun code Swift ne peut être compilé sur Windows. Chaque étape se vérifie par un build Codemagic puis par TestFlight sur un iPhone ; prévoir 15 à 20 minutes par essai.

## 4. Ce qu'il faut du propriétaire
1. Accord sur le plan (phases 1 et 2 d'abord) et sur la déclaration des coordonnées de visage.
2. Un iPhone de test avec TestFlight, et un build Codemagic par étape.
3. Après la phase 1 : essai d'une photo avec masque et beauté sur iPhone ; après la phase 2 : essai d'une courte vidéo avec filtre.

## 5. Taille estimée
Phases 1 et 2 : **moins de 0,5 Mo** (code Swift seulement). Phase 3 : à mesurer (Metal et AVFoundation sont dans iOS).
