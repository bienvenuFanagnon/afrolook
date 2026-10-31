/// Les abonnés sont prévenus par le serveur à la création d'une publication (POST /posts) : plus de traitement par lots côté application.
class MassNotificationService {
  Future<void> notifySubscribersAboutNewPost({
    required String postId,
    required String authorId,
  }) async {}

  Future<void> notifyViaCloudFunction(String postId, String authorId) async {}
}
