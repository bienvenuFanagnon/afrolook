import 'package:afrotok/l10n/tr.dart';
import 'package:flutter/material.dart';

/// Types de notifications ajoutés par le lot B2 de l'API et phrases (traduites) qui les décrivent dans la liste des notifications.
/// Le serveur envoie `title` = pseudo de l'auteur et `body` = extrait ou rien : la phrase est donc écrite ici, dans la langue de l'application.
class NotificationText {
  NotificationText._();

  /// Nouveaux types : mention, j'aime d'un commentaire, republication, soutien par pub, abonné à un canal.
  static const newTypes = {'MENTION', 'COMMENT_LIKE', 'REPOST', 'SUPPORT', 'FOLLOW_CANAL'};

  /// Groupes de la page (clé = libellé français, traduit à l'affichage), types rangés dans chacun et filtre « par type » correspondant.
  static const Map<String, List<String>> groupTypes = {
    'J\'aime': ['FAVORITE', 'LIKE', 'COMMENT_LIKE'],
    'Commentaires': ['COMMENT', 'COMMENTAIRE', 'REPLY', 'MENTION'],
    'Abonnés': ['ABONNER', 'FOLLOW_CANAL', 'INVITATION', 'ACCEPTINVITATION'],
    'Messages': ['MESSAGE'],
    'Publications & Lives': ['NEWPOST', 'POST', 'REPOST', 'LIVE', 'CHALLENGE'],
    'Articles & Contenus': ['ARTICLE', 'CHRONIQUE', 'SERVICE'],
    'Récompenses': ['WEEKLY_REWARD'],
    'Gains & Parrainages': ['GAIN', 'PARRAINAGE', 'SUPPORT'],
    'Afrolook': ['MARKETING', 'COMPTE_OFFICIEL', 'USER'],
  };

  /// Phrase affichée après le pseudo de l'auteur, ou null pour garder le texte envoyé par le serveur.
  /// [body] : extrait public (mention) ou titre du canal (nouvel abonné).
  static String? sentence(String? type, {String? body}) {
    final b = (body ?? '').trim();
    switch ((type ?? '').toUpperCase()) {
      case 'MENTION':
        return b.isEmpty ? tr('vous a mentionné') : '${tr('vous a mentionné')} : « $b »';
      case 'COMMENT_LIKE':
        return tr('a aimé votre commentaire');
      case 'REPOST':
        return tr('a republié votre publication');
      case 'SUPPORT':
        return tr('vous a soutenu en regardant une pub : +1 pièce');
      case 'FOLLOW_CANAL':
        return b.isEmpty ? tr('suit votre canal') : '${tr('suit votre canal')} « $b »';
      case 'LIKE':
        return b.isEmpty ? tr('a aimé votre publication') : null;
      case 'FAVORITE':
        return b.isEmpty ? tr('a ajouté votre publication à ses favoris') : null;
      case 'ABONNER':
        return b.isEmpty ? tr('s\'est abonné à votre compte') : null;
    }
    return null;
  }

  /// Nom lisible d'un type dans le filtre « par type » (le code brut pour les types plus anciens).
  static String typeLabel(String type) => switch (type.toUpperCase()) {
        'MENTION' => tr('Mentions'),
        'COMMENT_LIKE' => tr('J\'aime de commentaires'),
        'REPOST' => tr('Republications'),
        'SUPPORT' => tr('Soutiens par pub'),
        'FOLLOW_CANAL' => tr('Abonnés de canal'),
        _ => type,
      };

  /// Icône et couleur (rôle : 0 = danger, 1 = info, 2 = succès, 3 = avertissement) du type de notification.
  static ({IconData icon, int tone})? look(String? type) => switch ((type ?? '').toUpperCase()) {
        'MENTION' => (icon: Icons.alternate_email, tone: 1),
        'COMMENT_LIKE' => (icon: Icons.thumb_up_alt_outlined, tone: 0),
        'REPOST' => (icon: Icons.repeat, tone: 2),
        'SUPPORT' => (icon: Icons.volunteer_activism, tone: 3),
        'FOLLOW_CANAL' => (icon: Icons.campaign_outlined, tone: 1),
        'LIKE' => (icon: Icons.favorite, tone: 0),
        'REPLY' => (icon: Icons.reply, tone: 1),
        _ => null,
      };
}
