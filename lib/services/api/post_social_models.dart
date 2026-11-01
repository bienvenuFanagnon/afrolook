import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/l10n/tr.dart';

/// Lecture des réponses du lot B2 « publications » (republication, soutien par pub) et messages d'erreur traduits.
/// Aucune dépendance à Firebase ni à Flutter : ces fonctions se testent seules.

/// Réponse de `POST /posts/{id}/repost` : `{ok, already, reposts_count, shares_count}`.
class RepostResult {
  const RepostResult({required this.already, required this.repostsCount, required this.sharesCount});

  /// Vrai si la personne avait déjà republié (rien n'est recompté).
  final bool already;
  final int repostsCount;
  final int sharesCount;

  factory RepostResult.fromResponse(dynamic response) {
    final d = ApiClient.data(response);
    final m = d is Map ? d : const {};
    return RepostResult(
      already: m['already'] == true,
      repostsCount: (m['reposts_count'] as num?)?.toInt() ?? 0,
      sharesCount: (m['shares_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Réponse de `POST /posts/{id}/support-ad` : `{ok, coins, ad_support_count}`.
class AdSupportResult {
  const AdSupportResult({required this.coins, required this.adSupportCount});

  /// Pièces gagnées par le créateur (1), financées par la pub.
  final int coins;
  final int adSupportCount;

  factory AdSupportResult.fromResponse(dynamic response) {
    final d = ApiClient.data(response);
    final m = d is Map ? d : const {};
    return AdSupportResult(
      coins: (m['coins'] as num?)?.toInt() ?? 1,
      adSupportCount: (m['ad_support_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Bloc `reposted_by` d'une publication du fil des abonnements : le plus récent des comptes suivis qui l'ont republiée.
class RepostedBy {
  const RepostedBy({required this.id, required this.username, required this.avatarUrl, this.repostedAt});

  final String id;
  final String username;
  final String avatarUrl;
  final DateTime? repostedAt;

  /// Null si le bloc est absent ou sans identifiant.
  static RepostedBy? fromJson(dynamic j) {
    if (j is! Map || j['id'] == null) return null;
    return RepostedBy(
      id: '${j['id']}',
      username: '${j['username'] ?? ''}',
      avatarUrl: '${j['avatar_url'] ?? ''}',
      repostedAt: DateTime.tryParse('${j['reposted_at']}'),
    );
  }
}

/// Messages (dans la langue de l'application) pour les erreurs de la republication et du soutien par pub.
/// Les codes inconnus gardent le message envoyé par le serveur (en français) ; le réseau a son propre texte.
class PostSocialMessages {
  PostSocialMessages._();

  static String _network() => tr('Connexion impossible. Vérifie ta connexion puis réessaie.');

  static String _fallback(ApiException e, String fallback) => e.message.isNotEmpty ? e.message : fallback;

  /// Erreur de `POST /posts/{id}/repost`.
  static String repost(Object e) {
    if (e is! ApiException) return tr('Impossible de republier pour le moment. Réessaie.');
    if (e.isNetwork) return _network();
    return switch (e.code) {
      'cannot_repost_own' => tr('Tu ne peux pas republier ta propre publication.'),
      'not_repostable' => tr('Cette publication ne peut pas être republiée.'),
      'blocked' => tr('Tu ne peux pas republier cette publication.'),
      'not_found' => tr('Cette publication n\'est plus disponible.'),
      _ => _fallback(e, tr('Impossible de republier pour le moment. Réessaie.')),
    };
  }

  /// Erreur de `POST /posts/{id}/support-ad` (ou de la déclaration de la pub regardée).
  static String support(Object e) {
    if (e is! ApiException) return tr('Impossible de soutenir cette publication pour le moment. Réessaie.');
    if (e.isNetwork) return _network();
    return switch (e.code) {
      'ad_not_watched' => tr('La publicité n\'a pas pu être vérifiée. Regarde-la en entier puis réessaie.'),
      'already_supported_today' => tr('Tu as déjà soutenu cette publication aujourd\'hui. Reviens demain !'),
      'cannot_support_own' => tr('Tu ne peux pas soutenir ta propre publication.'),
      'not_supportable' => tr('Cette publication ne peut pas être soutenue.'),
      'not_found' => tr('Cette publication n\'est plus disponible.'),
      _ => _fallback(e, tr('Impossible de soutenir cette publication pour le moment. Réessaie.')),
    };
  }

  /// Pour le soutien, ces erreurs n'ont pas de sens à « Réessayer » (la règle ne changera pas).
  static bool supportRetryable(Object e) {
    if (e is! ApiException) return true;
    return !const {'already_supported_today', 'cannot_support_own', 'not_supportable', 'not_found'}.contains(e.code);
  }
}
