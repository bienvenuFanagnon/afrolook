import UserNotifications
import FirebaseMessaging

/// Extension de service de notification (iPhone) : télécharge l'image d'aperçu envoyée par le serveur (`fcm_options.image`) et l'attache à la
/// notification, pour qu'on voie la photo, la miniature de vidéo ou la pochette de musique. Sans cette extension, iOS affiche le texte seul.
/// Mise en place : voir ios/NOTIFICATION_IMAGES_IOS.md.
class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
    guard let content = bestAttemptContent else {
      contentHandler(request.content)
      return
    }
    // Firebase télécharge l'image indiquée dans le message et l'ajoute en pièce jointe
    Messaging.serviceExtension().populateNotificationContent(content, withContentHandler: contentHandler)
  }

  override func serviceExtensionTimeWillExpire() {
    // Temps écoulé : on affiche quand même la notification (sans l'image)
    if let contentHandler = contentHandler, let content = bestAttemptContent {
      contentHandler(content)
    }
  }
}
