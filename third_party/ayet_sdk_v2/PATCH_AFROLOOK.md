# Copie d'ayet_sdk_v2 1.0.4 (Afrolook) : Android seulement

Le plugin publié exige **Swift Package Manager** sur iPhone (son podspec ne contient aucun fichier source), alors que `codemagic.yaml` le désactive
(`flutter config --no-enable-swift-package-manager`) : avec le plugin tel quel, la compilation iPhone échouerait.

Cette copie ne déclare donc que **Android** (dossier `ios` retiré, section `ios:` du `pubspec.yaml` retirée). Sur iPhone, ayeT est simplement absent :
le code de l'application ne l'appelle que si `AYET_PLACEMENT_ID_IOS` est renseigné (voir lib/services/offerwall/offerwall_service.dart).

Pour activer ayeT sur iPhone plus tard : reprendre le plugin publié, activer Swift Package Manager (ou héberger le SDK iOS en CocoaPods) et valider sur Codemagic.
