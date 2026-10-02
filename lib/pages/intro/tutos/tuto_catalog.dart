import 'package:flutter/material.dart';

import 'tuto_layouts.dart';

import '../../../utils/platform_guard.dart';
import '../../canaux/listCanauxByUser.dart';
import '../../chat/group/create_group_page.dart';
import '../../contenuPayant/contentForm.dart';
import '../../defi/defi_discover_page.dart';
import '../../user/UserRetrait/userRetraitForm.dart';
import '../../user/monetisation.dart';
import '../../user/userPubs/user_profile_boost_page.dart';

/// Élément de la maquette d'écran d'un tutoriel (reproduction simplifiée de la vraie page).
enum MockKind { cover, profile, line, tile, button, chips, big }

class MockEl {
  final MockKind kind;
  final String a; // titre / texte principal
  final String b; // sous-titre / valeur
  final String trailing; // '', 'on', 'off', ou texte court (ex. « +2 🪙 »)
  final int color; // bouton : 0 vert, 1 or, 2 rose
  final List<String> items; // chips

  const MockEl(this.kind, {this.a = '', this.b = '', this.trailing = '', this.color = 0, this.items = const []});

  double get height {
    switch (kind) {
      case MockKind.cover: return 62;
      case MockKind.profile: return 46;
      case MockKind.line: return 8;
      case MockKind.tile: return b.isEmpty ? 36 : 44;
      case MockKind.button: return 38;
      case MockKind.chips: return 26;
      case MockKind.big: return 62;
    }
  }
}

/// Une scène de tutoriel : la vraie page de l'app, l'action clé mise en lumière, puis le gain.
/// Ordre de lecture identique partout : page → action en lumière → gain qui tombe → bouton d'action.
/// Aucun montant en argent : tout est en pièces (règle App Store).
class TutoScene {
  final String id;
  final String emoji;
  final String title;
  final String hook;
  final String screenTitle;
  final List<MockEl> els;
  final int target; // index de l'élément mis en lumière
  /// 'std' = maquette d'éléments ; sinon écran fidèle : live, live_prive, comments, post.
  final String layout;
  final TutoSpot? spot; // zone mise en lumière pour les écrans fidèles
  final String hint; // bulle qui explique l'action
  final String gainEmoji;
  final String gainTitle;
  final String gainSub;
  final String earn; // ce que le créateur peut gagner (exemple à titre indicatif)
  final String actionLabel;
  final void Function(BuildContext context)? action;
  final bool publicScene;
  final bool hiddenOnIOS;

  const TutoScene({
    required this.id,
    required this.emoji,
    required this.title,
    required this.hook,
    required this.screenTitle,
    this.els = const [],
    this.target = 0,
    this.layout = 'std',
    this.spot,
    required this.hint,
    required this.gainEmoji,
    required this.gainTitle,
    required this.gainSub,
    required this.earn,
    required this.actionLabel,
    this.action,
    this.publicScene = true,
    this.hiddenOnIOS = false,
  });
}

void _push(BuildContext c, Widget page) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => page));

/// Les tutoriels de rémunération, du plus simple au plus avancé.
/// (Le « Tutoriel de monétisation » animé d'origine reste le créneau 0 de la rotation.)
final List<TutoScene> kTutoScenes = [
  TutoScene(
    id: 'likes', emoji: '❤️', title: 'Les likes paient', hook: 'Chaque like sur tes posts te rapporte des pièces.',
    screenTitle: 'Détails du post', layout: 'post', spot: tutoSpotPostLikes,
    hint: 'Chaque like te rapporte 1 pièce',
    gainEmoji: '🪙', gainTitle: '+3 200 pièces', gainSub: 'pour 3 200 likes',
    earn: 'Exemple : un post à 3 200 likes = 3 200 pièces pour toi',
    actionLabel: 'Créer un post', action: (c) => Navigator.of(c).pushNamed('/user_posts_form'),
  ),
  TutoScene(
    id: 'cadeaux', emoji: '🎁', title: 'Les cadeaux en pièces', hook: 'Tes fans t’offrent des pièces directement sur tes posts.',
    screenTitle: 'Détails du post', layout: 'post', spot: tutoSpotPostGifts,
    hint: 'Un fan t’offre un cadeau en pièces',
    gainEmoji: '🎁', gainTitle: '+120 pièces', gainSub: 'cadeau « Couronne » reçu',
    earn: 'Chaque cadeau reçu est crédité en pièces sur ton portefeuille',
    actionLabel: 'Voir mon portefeuille', action: (c) => _push(c, MonetisationPage()),
  ),
  TutoScene(
    id: 'commentaires', emoji: '💬', title: 'Les commentaires paient', hook: 'Un bon commentaire rapporte, et ceux qui l’aiment aussi.',
    screenTitle: 'Commentaires', layout: 'comments', spot: tutoSpotCommentInput,
    hint: 'Un like ou un cadeau sur un commentaire rapporte à son auteur',
    gainEmoji: '💬', gainTitle: '+150 pièces', gainSub: 'pour 150 commentaires, plus les likes reçus',
    earn: 'Exemple : 150 commentaires = 150 pièces ; chaque like sur ton commentaire = 1 pièce de plus',
    actionLabel: 'Créer un post', action: (c) => Navigator.of(c).pushNamed('/user_posts_form'),
  ),
  TutoScene(
    id: 'vues', emoji: '👁️', title: 'Les vues comptent', hook: 'Plus ton contenu est vu, plus tu gagnes.',
    screenTitle: 'Mes gains',
    els: const [
      MockEl(MockKind.big, a: 'Vues ce mois-ci', b: '48 200 👁'),
      MockEl(MockKind.tile, a: 'Gains des vues', b: 'À encaisser', trailing: '💰'),
      MockEl(MockKind.button, a: 'Encaisser mes gains', color: 1),
    ],
    target: 2, hint: 'Encaisse tes gains en 1 clic',
    gainEmoji: '💰', gainTitle: 'Gains encaissés', gainSub: 'ajoutés à ton portefeuille',
    earn: 'Chaque vue rémunérée s’ajoute à tes gains : encaisse-les quand tu veux',
    actionLabel: 'Voir mes gains', action: (c) => _push(c, MonetisationPage()),
  ),
  TutoScene(
    id: 'defi', emoji: '🏆', title: 'Les DÉFIs', hook: 'Participe, fais voter, remporte la cagnotte.',
    screenTitle: 'DÉFI',
    els: const [
      MockEl(MockKind.cover),
      MockEl(MockKind.tile, a: '🏆 Cagnotte', b: 'Pour les gagnants', trailing: '1 500 🪙'),
      MockEl(MockKind.tile, a: 'Participants', trailing: '34'),
      MockEl(MockKind.button, a: 'Participer au DÉFI', color: 1),
    ],
    target: 3, hint: 'Participe et fais voter ta communauté',
    gainEmoji: '🏆', gainTitle: 'Cagnotte remportée', gainSub: 'les meilleurs se la partagent',
    earn: 'Les gagnants du DÉFI se partagent la cagnotte',
    actionLabel: 'Découvrir les DÉFIs', action: (c) => _push(c, const DefiDiscoverPage()), publicScene: false,
  ),
  TutoScene(
    id: 'canal_prive', emoji: '📺', title: 'Canal privé par abonnement', hook: 'Tes abonnés paient pour te suivre.',
    screenTitle: 'Mon canal',
    els: const [
      MockEl(MockKind.cover),
      MockEl(MockKind.profile, a: '#StyleAfro', b: '342 abonnés'),
      MockEl(MockKind.button, a: 'S’ABONNER · 300 pièces', color: 1),
      MockEl(MockKind.tile, a: '🔒 Publications réservées'),
    ],
    target: 2, hint: 'Fixe un prix d’abonnement en pièces',
    gainEmoji: '🪙', gainTitle: '+210 pièces', gainSub: 'à chaque nouvel abonné',
    earn: 'Exemple : 50 abonnés à 300 pièces = 10 500 pièces pour toi',
    actionLabel: 'Créer un canal', action: (c) => _push(c, CanalListPageByUser()), publicScene: false,
  ),
  TutoScene(
    id: 'contenu_payant', emoji: '🎬', title: 'Contenu à paiement unique', hook: 'Vends une vidéo, un ebook ou une formation, une seule fois.',
    screenTitle: 'Mon contenu',
    els: const [
      MockEl(MockKind.cover),
      MockEl(MockKind.tile, a: 'Formation vidéo', b: 'Tu fixes le prix'),
      MockEl(MockKind.button, a: 'Publier le contenu', color: 1),
    ],
    target: 2, hint: 'Fixe ton prix et publie',
    gainEmoji: '🎬', gainTitle: 'Chaque achat te rapporte', gainSub: 'paiement unique',
    earn: 'Tu fixes le prix : chaque achat de ton contenu t’est reversé',
    actionLabel: 'Ajouter un contenu', action: (c) => _push(c, ContentFormScreen()), publicScene: false, hiddenOnIOS: true,
  ),
  TutoScene(
    id: 'groupes', emoji: '👥', title: 'Groupes privés payants', hook: 'Fais payer l’accès à ton groupe privé.',
    screenTitle: 'Info groupe',
    els: const [
      MockEl(MockKind.profile, a: 'Afro Créateurs', b: '128 membres'),
      MockEl(MockKind.line),
      MockEl(MockKind.tile, a: 'Mode lecture seule', trailing: 'off'),
      MockEl(MockKind.tile, a: 'Groupe privé payant', b: '250 pièces / mois', trailing: 'on'),
      MockEl(MockKind.tile, a: 'Ajouter un membre', trailing: '›'),
    ],
    target: 3, hint: 'Active « Groupe privé payant » et fixe ton prix',
    gainEmoji: '🪙', gainTitle: '+175 pièces', gainSub: 'à chaque entrée dans ton groupe',
    earn: 'Exemple : 40 entrées à 250 pièces = 7 000 pièces pour toi',
    actionLabel: 'Créer un groupe', action: (c) => _push(c, const CreateGroupPage()), publicScene: false,
  ),
  TutoScene(
    id: 'lives', emoji: '🔴', title: 'Les lives', hook: 'Passe en direct et reçois des cadeaux en temps réel.',
    screenTitle: 'Live', layout: 'live', spot: tutoSpotLiveGifts,
    hint: 'Tes spectateurs t’envoient des cadeaux',
    gainEmoji: '🪙', gainTitle: '+140 pièces', gainSub: 'ce live t’a déjà rapporté',
    earn: 'Les cadeaux du live s’ajoutent en direct à tes pièces',
    actionLabel: 'Lancer un live', action: (c) => Navigator.of(c).pushNamed('/create_live'), publicScene: false,
  ),
  TutoScene(
    id: 'live_prive', emoji: '🔒', title: 'Lives privés payants', hook: 'Fais payer l’entrée de ton live.',
    screenTitle: 'Live privé', layout: 'live_prive', spot: tutoSpotLivePay,
    hint: 'Chaque spectateur paie son entrée en pièces',
    gainEmoji: '🪙', gainTitle: '+70 pièces', gainSub: 'à chaque nouvelle entrée',
    earn: 'Exemple : 30 entrées à 100 pièces = 2 100 pièces pour toi',
    actionLabel: 'Lancer un live', action: (c) => Navigator.of(c).pushNamed('/create_live'), publicScene: false,
  ),
  TutoScene(
    id: 'parrainage', emoji: '🤝', title: 'Parrainage', hook: 'Invite tes amis et gagne avec eux.',
    screenTitle: 'Mes amis',
    els: const [
      MockEl(MockKind.big, a: 'Ton code', b: 'AFRO-4821'),
      MockEl(MockKind.button, a: 'Partager mon code'),
      MockEl(MockKind.tile, a: '3 amis inscrits', trailing: '✓'),
    ],
    target: 1, hint: 'Partage ton code : ton ami s’inscrit avec',
    gainEmoji: '🤝', gainTitle: 'Tu gagnes avec eux', gainSub: 'sur leurs achats',
    earn: 'Chaque ami parrainé te rapporte une commission sur ses achats',
    actionLabel: 'Inviter mes amis', action: (c) => Navigator.of(c).pushNamed('/amis'), publicScene: false,
  ),
  TutoScene(
    id: 'boost', emoji: '🚀', title: 'Boost et publicités', hook: 'Fais voir ton profil ou ton post à plus de monde.',
    screenTitle: 'Booster mon profil',
    els: const [
      MockEl(MockKind.profile, a: '@nadia.vibes', b: '12,4 k abonnés'),
      MockEl(MockKind.tile, a: 'Durée', trailing: '7 jours'),
      MockEl(MockKind.button, a: 'Booster · payé en pièces', color: 1),
    ],
    target: 2, hint: 'Paie en pièces : ton profil est mis en avant',
    gainEmoji: '🚀', gainTitle: 'Plus de vues', gainSub: 'donc plus d’abonnés et de gains',
    earn: 'Ton profil est montré à plus de monde, donc tes gains grandissent',
    actionLabel: 'Booster mon profil', action: (c) => _push(c, UserProfileBoostPage()), publicScene: false,
  ),
  TutoScene(
    id: 'retrait', emoji: '💸', title: 'Retirer tes gains', hook: 'Tes pièces se convertissent en argent réel.',
    screenTitle: 'Mon portefeuille',
    els: const [
      MockEl(MockKind.big, a: 'Pièces gagnées', b: '1 240 🪙'),
      MockEl(MockKind.tile, a: 'Pièces achetées', trailing: '300'),
      MockEl(MockKind.button, a: 'Demander un retrait'),
      MockEl(MockKind.chips, items: ['Mobile Money', 'Virement', 'PayPal']),
    ],
    target: 2, hint: 'Choisis ton moyen de retrait',
    gainEmoji: '✅', gainTitle: 'Retrait envoyé', gainSub: 'tu le reçois sur ton compte',
    earn: 'Tes pièces gagnées sont retirables à tout moment, selon le minimum en vigueur',
    actionLabel: 'Demander un retrait', action: (c) => _push(c, UserDemandeRetraitPage()), publicScene: false,
  ),
];

/// Scènes disponibles sur la plateforme courante ([publicOnly] : avant la connexion).
List<TutoScene> tutoScenesAvailable({bool publicOnly = false}) =>
    kTutoScenes.where((s) => !(kIsAppleStore && s.hiddenOnIOS) && (!publicOnly || s.publicScene)).toList();
