# iPhone : images et son des notifications

Ce qui marche **déjà** sur iPhone, sans rien faire de plus :

- **Icône** : iOS utilise automatiquement l'icône de l'application (pas de petite icône à fournir, contrairement à Android).
- **Son Afrolook** : `Runner/afrolook_chime.wav` est maintenant dans le projet Xcode (cible Runner, ressources). Le serveur envoie
  `aps.sound = afrolook_chime.wav`.
- **Texte, ouverture de la bonne page au toucher, notifications quand l'application est ouverte** : gérés par `PushService`.
- **Clé APNs** : déjà importée dans Firebase (production).

## Une étape manuelle (sur le Mac) : l'image d'aperçu

iOS n'affiche une **image** dans une notification que si l'application embarque une *extension de service de notification*. Le serveur envoie déjà
tout ce qu'il faut (`mutable-content` et `fcm_options.image`). Il reste à créer l'extension, une seule fois :

1. Ouvrir `ios/Runner.xcworkspace` dans Xcode.
2. **File › New › Target… › Notification Service Extension**.
   - Product Name : `NotificationServiceExtension`
   - Bundle Identifier : `com.afrotok.afrotok.NotificationServiceExtension`
   - Language : Swift. Si Xcode propose d'activer le schéma, accepter.
3. Remplacer le contenu de `NotificationService.swift` créé par Xcode par celui de
   `ios/NotificationServiceExtension/NotificationService.swift` (déjà écrit).
4. Réglages de la cible `NotificationServiceExtension` :
   - **Signing** : même équipe (Team ID `3Y2P43MBK8`).
   - **Minimum Deployments** : même version d'iOS que Runner.
   - **Version / Build** : identiques à Runner (sinon l'App Store refuse l'envoi). Dans *Build Settings* : `MARKETING_VERSION = $(FLUTTER_BUILD_NAME)` et
     `CURRENT_PROJECT_VERSION = $(FLUTTER_BUILD_NUMBER)`.
5. Dans `ios/Podfile`, ajouter à la fin (hors du bloc `target 'Runner'`) :

   ```ruby
   target 'NotificationServiceExtension' do
     use_frameworks!
     pod 'Firebase/Messaging'
   end
   ```

6. Dans un terminal, `cd ios && pod install --repo-update`, puis compiler.

Test : Admin › Essai notifications › Moi, avec un contenu qui a une image (ex. un post photo) ; l'image doit apparaître en bas de la notification
sur un iPhone (appui long ou balayage vers le bas pour la déplier).

## Vérifier sur un vrai iPhone
- Les notifications ne fonctionnent pas sur simulateur.
- Accepter la demande d'autorisation au premier lancement ; si elle a été refusée : Réglages › Afrolook › Notifications.
- Admin › Essai notifications › Moi doit afficher « FCM : 1 appareil » puis un envoi par le canal FCM.
