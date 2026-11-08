import 'package:afrotok/l10n/tr.dart';
import 'package:flutter/material.dart';

/// Types de notifications ajoutés par le lot B2 de l'API et phrases (traduites) qui les décrivent dans la liste des notifications.
/// Le serveur envoie `title` = pseudo de l'auteur et `body` = extrait ou rien : la phrase est donc écrite ici, dans la langue de l'application.
class NotificationText {
  NotificationText._();

  /// Nouveaux types : mention, j'aime d'un commentaire, republication, soutien par pub, abonné à un canal,
  /// puis (lot « restes ») boost à valider (équipe), nomination comme administrateur d'un canal, intérêt pour un service.
  static const newTypes = {'VIDEO_REPLY', 'MENTION', 'COMMENT_LIKE', 'REPOST', 'SUPPORT', 'FOLLOW_CANAL', 'BOOST_SOUMIS', 'CANAL_ADMIN', 'SERVICE', 'STAFF_VERIF', 'STAFF_FRAUD', 'STAFF_DISPUTE', 'STAFF_ADS'};

  /// Groupes de la page (clé = libellé français, traduit à l'affichage), types rangés dans chacun et filtre « par type » correspondant.
  static const Map<String, List<String>> groupTypes = {
    'J\'aime': ['FAVORITE', 'LIKE', 'COMMENT_LIKE'],
    'Commentaires': ['COMMENT', 'COMMENTAIRE', 'REPLY', 'MENTION', 'VIDEO_REPLY'],
    'Abonnés': ['ABONNER', 'FOLLOW_CANAL', 'CANAL_ADMIN', 'INVITATION', 'ACCEPTINVITATION'],
    'Messages': ['MESSAGE'],
    'Publications & Lives': ['NEWPOST', 'POST', 'REPOST', 'LIVE', 'CHALLENGE', 'FRIEND_ACTIVITY'],
    'Articles & Contenus': ['ARTICLE', 'CHRONIQUE', 'SERVICE'],
    'Récompenses': ['WEEKLY_REWARD'],
    'Commandes': ['ORDER_NEW', 'ORDER_VALIDATED', 'ORDER_FEE', 'ORDER_SHIPPED', 'ORDER_RECEIVED', 'ORDER_CANCELLED', 'ORDER_DISPUTE', 'ORDER_RESOLVED', 'OFFER_NEW', 'OFFER_REPLY'],
    'Gains & Parrainages': ['GAIN', 'PARRAINAGE', 'SUPPORT'],
    'Afrolook': ['MARKETING', 'COMPTE_OFFICIEL', 'USER', 'BOOST_SOUMIS'],
    'À traiter (équipe)': ['STAFF_VERIF', 'STAFF_FRAUD', 'STAFF_DISPUTE', 'STAFF_ADS'],
  };

  /// Phrase affichée après le pseudo de l'auteur, ou null pour garder le texte envoyé par le serveur.
  /// [body] : extrait public (mention) ou titre du canal (nouvel abonné).
  static String? sentence(String? type, {String? body}) {
    final b = (body ?? '').trim();
    switch ((type ?? '').toUpperCase()) {
      case 'FRIEND_ACTIVITY':
        // le serveur envoie « action|pseudo de l'auteur de la publication » (action : like, comment ou repost)
        final parts = b.split('|');
        final who = parts.length > 1 && parts[1].isNotEmpty ? '@${parts[1]}' : tr('un ami');
        final verb = switch (parts.first) {
          'comment' => tr('a commenté la publication de {who}', {'who': who}),
          'repost' => tr('a republié la publication de {who}', {'who': who}),
          _ => tr('a aimé la publication de {who}', {'who': who}),
        };
        return verb;
      case 'MENTION':
        return b.isEmpty ? tr('vous a mentionné') : '${tr('vous a mentionné')} : « $b »';
      case 'ORDER_NEW':
        return b.isEmpty ? tr('vous a passé une commande') : '${tr('vous a passé une commande')} : $b';
      case 'ORDER_VALIDATED':
        return tr('a validé la commande');
      case 'ORDER_FEE':
        return tr('a modifié les frais de livraison : acceptez-les ou refusez');
      case 'ORDER_SHIPPED':
        return tr('a expédié votre commande');
      case 'ORDER_RECEIVED':
        return tr("a confirmé la réception : l'argent est versé");
      case 'ORDER_CANCELLED':
        return tr('a annulé la commande');
      case 'ORDER_DISPUTE':
        return tr('a signalé un problème sur la commande');
      case 'ORDER_RESOLVED':
        return tr("L'équipe a tranché le litige de la commande");
      case 'OFFER_NEW':
        return b.isEmpty ? tr('propose un prix sur votre article') : '${tr('propose un prix sur votre article')} : $b';
      case 'OFFER_REPLY':
        return tr('a répondu à votre offre');
      case 'VIDEO_REPLY':
        return tr('vous a répondu en vidéo');
      case 'COMMENT_LIKE':
        return tr('a aimé votre commentaire');
      case 'REPOST':
        return tr('a republié votre publication');
      case 'SUPPORT':
        return tr('vous a soutenu en regardant une pub : +1 pièce');
      case 'FOLLOW_CANAL':
        return b.isEmpty ? tr('suit votre canal') : '${tr('suit votre canal')} « $b »';
      case 'BOOST_SOUMIS':
        // body : « Publication : titre — 2 semaines »
        return b.isEmpty ? tr('a soumis un boost à valider') : '${tr('a soumis un boost à valider')} : $b';
      case 'STAFF_VERIF':
        return tr('demande la vérification de son identité de vendeur');
      case 'STAFF_FRAUD':
        return b.isEmpty ? tr('a des gains de partage bloqués : détection de fraude à vérifier') : '${tr('a des gains de partage bloqués : détection de fraude à vérifier')} : $b';
      case 'STAFF_ADS':
        // body : « Annonceur · secteur · pays », « Diffuseur · type · pays », « Site web · catégorie · pays », « Annonce gratuite · titre · pays », « Campagne Partage · titre · audience »
        return b.isEmpty ? tr('a envoyé un élément Afrolook Ads à valider') : '${tr('a envoyé un élément Afrolook Ads à valider')} : $b';
      case 'STAFF_DISPUTE':
        return b.isEmpty ? tr('a ouvert un litige sur une commande') : '${tr('a ouvert un litige sur une commande')} « $b »';
      case 'CANAL_ADMIN':
        return b.isEmpty ? tr('vous a nommé administrateur de son canal') : '${tr('vous a nommé administrateur de son canal')} « $b »';
      case 'SERVICE':
        return b.isEmpty ? tr('s\'intéresse à votre service') : '${tr('s\'intéresse à votre service')} « $b »';
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
        'VIDEO_REPLY' => tr('Réponses en vidéo'),
        'MENTION' => tr('Mentions'),
        'COMMENT_LIKE' => tr('J\'aime de commentaires'),
        'REPOST' => tr('Republications'),
        'SUPPORT' => tr('Soutiens par pub'),
        'FOLLOW_CANAL' => tr('Abonnés de canal'),
        'BOOST_SOUMIS' => tr('Boosts à valider'),
        'STAFF_VERIF' => tr('Identités de vendeurs à vérifier'),
        'STAFF_FRAUD' => tr('Gains bloqués (fraude)'),
        'STAFF_DISPUTE' => tr('Litiges de commande'),
        'STAFF_ADS' => tr('Éléments Afrolook Ads à valider'),
        'CANAL_ADMIN' => tr('Nominations de canal'),
        'SERVICE' => tr('Intérêt pour un service'),
        _ => type,
      };

  /// Icône et couleur (rôle : 0 = danger, 1 = info, 2 = succès, 3 = avertissement) du type de notification.
  static ({IconData icon, int tone})? look(String? type) => switch ((type ?? '').toUpperCase()) {
        'VIDEO_REPLY' => (icon: Icons.videocam_outlined, tone: 2),
        'MENTION' => (icon: Icons.alternate_email, tone: 1),
        'COMMENT_LIKE' => (icon: Icons.thumb_up_alt_outlined, tone: 0),
        'REPOST' => (icon: Icons.repeat, tone: 2),
        'SUPPORT' => (icon: Icons.volunteer_activism, tone: 3),
        'FOLLOW_CANAL' => (icon: Icons.campaign_outlined, tone: 1),
        'BOOST_SOUMIS' => (icon: Icons.rocket_launch_outlined, tone: 3),
        'STAFF_VERIF' => (icon: Icons.badge_outlined, tone: 3),
        'STAFF_FRAUD' => (icon: Icons.shield_outlined, tone: 0),
        'STAFF_DISPUTE' => (icon: Icons.gavel_rounded, tone: 0),
        'STAFF_ADS' => (icon: Icons.storefront_outlined, tone: 3),
        'CANAL_ADMIN' => (icon: Icons.admin_panel_settings_outlined, tone: 1),
        'SERVICE' => (icon: Icons.handyman, tone: 2),
        'LIKE' => (icon: Icons.favorite, tone: 0),
        'REPLY' => (icon: Icons.reply, tone: 1),
        _ => null,
      };
}
