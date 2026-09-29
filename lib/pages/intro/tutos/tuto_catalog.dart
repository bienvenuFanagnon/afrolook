import 'package:flutter/material.dart';

import '../../../utils/platform_guard.dart';
import '../../canaux/listCanauxByUser.dart';
import '../../chat/group/create_group_page.dart';
import '../../contenuPayant/contentForm.dart';
import '../../defi/defi_discover_page.dart';
import '../../user/UserRetrait/userRetraitForm.dart';
import '../../user/monetisation.dart';
import '../../user/userPubs/user_profile_boost_page.dart';

/// Une scène de tutoriel = une carte courte, toujours dans le même ordre de lecture :
/// 1) l'accroche (le gain en une phrase) → 2) trois étapes → 3) le chiffre clé → 4) le bouton d'action.
/// Aucun montant en argent : tout est exprimé en pièces (règle App Store).
class TutoScene {
  final String id;
  final String emoji;
  final String title;
  final String hook;
  final List<String> steps;
  final String figure;
  final String figureLabel;
  final String actionLabel;
  /// Ouvre la page liée à la scène (null → « Créer un post » par défaut côté appelant).
  final void Function(BuildContext context)? action;
  /// Scène affichable sans être connecté (avant login) ?
  final bool publicScene;
  /// Masquée sur iPhone/iPad (prix en argent, non conforme App Store).
  final bool hiddenOnIOS;

  const TutoScene({
    required this.id,
    required this.emoji,
    required this.title,
    required this.hook,
    required this.steps,
    required this.figure,
    required this.figureLabel,
    required this.actionLabel,
    this.action,
    this.publicScene = true,
    this.hiddenOnIOS = false,
  });
}

void _push(BuildContext c, Widget page) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => page));

/// Les tutoriels de rémunération, du plus simple au plus avancé.
/// (Le tutoriel « like » animé historique reste la scène 0 des feeds.)
final List<TutoScene> kTutoScenes = [
  TutoScene(
    id: 'likes',
    emoji: '❤️',
    title: 'Les likes paient',
    hook: 'Chaque like sur tes posts te rapporte des pièces.',
    steps: ['Publie un post', 'Tes abonnés le like', '1 pièce arrive dans ton portefeuille'],
    figure: '1 like = 1 pièce',
    figureLabel: 'sans limite',
    actionLabel: 'Créer un post',
    action: (c) => Navigator.of(c).pushNamed('/user_posts_form'),
  ),
  TutoScene(
    id: 'cadeaux',
    emoji: '🎁',
    title: 'Les cadeaux en pièces',
    hook: 'Tes fans t’offrent des pièces directement sur tes posts.',
    steps: ['Un fan ouvre ton post', 'Il choisit un cadeau', 'Les pièces te sont créditées'],
    figure: '100 % en pièces',
    figureLabel: 'retirables selon les règles',
    actionLabel: 'Voir mon portefeuille',
    action: (c) => _push(c, MonetisationPage()),
  ),
  TutoScene(
    id: 'commentaires',
    emoji: '💬',
    title: 'Les commentaires paient',
    hook: 'Une bonne conversation rapporte aussi.',
    steps: ['Publie un post qui fait réagir', 'Ta communauté commente', 'Chaque commentaire te rapporte'],
    figure: '2 pièces',
    figureLabel: 'par commentaire',
    actionLabel: 'Créer un post',
    action: (c) => Navigator.of(c).pushNamed('/user_posts_form'),
  ),
  TutoScene(
    id: 'vues',
    emoji: '👁️',
    title: 'Les vues comptent',
    hook: 'Plus ton contenu est vu, plus tu gagnes.',
    steps: ['Publie régulièrement', 'Tes vues sont comptées', 'Tu encaisses tes gains'],
    figure: 'Encaissement en 1 clic',
    figureLabel: 'depuis Mes gains',
    actionLabel: 'Voir mes gains',
    action: (c) => _push(c, MonetisationPage()),
  ),
  TutoScene(
    id: 'defi',
    emoji: '🏆',
    title: 'Les DÉFIs',
    hook: 'Participe, fais voter, remporte la cagnotte.',
    steps: ['Choisis un DÉFI', 'Participe avec ta vidéo ou photo', 'Les meilleurs se partagent la cagnotte'],
    figure: 'Cagnotte pour les gagnants',
    figureLabel: 'l’app ne prend qu’une commission',
    actionLabel: 'Découvrir les DÉFIs',
    action: (c) => _push(c, const DefiDiscoverPage()),
    publicScene: false,
  ),
  TutoScene(
    id: 'canal_prive',
    emoji: '📺',
    title: 'Canal privé par abonnement',
    hook: 'Ouvre un canal réservé à tes abonnés payants.',
    steps: ['Crée ton canal', 'Fixe un abonnement en pièces', 'Tes abonnés paient pour te suivre'],
    figure: 'Revenu récurrent',
    figureLabel: 'chaque abonnement renouvelé',
    actionLabel: 'Créer un canal',
    action: (c) => _push(c, CanalListPageByUser()),
    publicScene: false,
  ),
  TutoScene(
    id: 'contenu_payant',
    emoji: '🎬',
    title: 'Contenu à paiement unique',
    hook: 'Vends une vidéo, un ebook ou une formation, une seule fois.',
    steps: ['Ajoute ton contenu', 'Fixe son prix', 'Chaque achat te rapporte'],
    figure: 'Tu fixes le prix',
    figureLabel: 'paiement unique',
    actionLabel: 'Ajouter un contenu',
    action: (c) => _push(c, ContentFormScreen()),
    publicScene: false,
    hiddenOnIOS: true,
  ),
  TutoScene(
    id: 'groupes',
    emoji: '👥',
    title: 'Groupes privés payants',
    hook: 'Fais payer l’accès à ton groupe privé.',
    steps: ['Crée un groupe', 'Rends-le payant avec un code d’accès', 'Tu touches ta part à chaque entrée'],
    figure: '70 % pour toi',
    figureLabel: '30 % pour l’app',
    actionLabel: 'Créer un groupe',
    action: (c) => _push(c, const CreateGroupPage()),
    publicScene: false,
  ),
  TutoScene(
    id: 'lives',
    emoji: '🔴',
    title: 'Les lives',
    hook: 'Passe en direct et reçois des cadeaux en temps réel.',
    steps: ['Lance ton live', 'Tes spectateurs envoient des cadeaux', 'Les pièces s’ajoutent pendant le direct'],
    figure: 'Un live à la fois',
    figureLabel: 'durée maximale appliquée',
    actionLabel: 'Lancer un live',
    action: (c) => Navigator.of(c).pushNamed('/create_live'),
    publicScene: false,
  ),
  TutoScene(
    id: 'parrainage',
    emoji: '🤝',
    title: 'Parrainage',
    hook: 'Invite tes amis et gagne avec eux.',
    steps: ['Partage ton code', 'Ton ami s’inscrit avec', 'Tu profites de ses activités'],
    figure: 'Ton code, ton réseau',
    figureLabel: 'visible dans Mes amis',
    actionLabel: 'Inviter mes amis',
    action: (c) => Navigator.of(c).pushNamed('/amis'),
    publicScene: false,
  ),
  TutoScene(
    id: 'boost',
    emoji: '🚀',
    title: 'Boost et publicités',
    hook: 'Fais voir ton profil ou ton post à plus de monde.',
    steps: ['Choisis ce que tu veux booster', 'Paie en pièces', 'Ton audience grandit'],
    figure: 'Plus de vues',
    figureLabel: 'donc plus de gains',
    actionLabel: 'Booster mon profil',
    action: (c) => _push(c, UserProfileBoostPage()),
    publicScene: false,
  ),
  TutoScene(
    id: 'retrait',
    emoji: '💸',
    title: 'Retirer tes gains',
    hook: 'Tes pièces se convertissent en argent réel.',
    steps: ['Cumule tes pièces gagnées', 'Demande ton retrait', 'Reçois-le par Mobile Money, virement ou PayPal'],
    figure: 'Retrait à tout moment',
    figureLabel: 'selon le minimum en vigueur',
    actionLabel: 'Demander un retrait',
    action: (c) => _push(c, UserDemandeRetraitPage()),
    publicScene: false,
  ),
];

/// Scènes disponibles sur la plateforme courante ([publicOnly] : avant la connexion).
List<TutoScene> tutoScenesAvailable({bool publicOnly = false}) =>
    kTutoScenes.where((s) => !(kIsAppleStore && s.hiddenOnIOS) && (!publicOnly || s.publicScene)).toList();
