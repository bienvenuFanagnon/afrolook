import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../services/navigation_service.dart';
import '../postDetails.dart';

/// Définition des routes internes disponibles pour le bouton d'action des pubs.
/// Seul un admin (rôle ADM) peut configurer une route interne.
class AdRoute {
  final String route;
  final String label;
  final String description;
  final IconData icon;
  const AdRoute({required this.route, required this.label, required this.description, required this.icon});
}

/// Liste des routes internes utilisables dans une pub (avec descriptions lisibles).
const List<AdRoute> kAdAppRoutes = [
  AdRoute(route: '/home',                label: 'Accueil',               description: 'Fil d\'actualité principal',              icon: Icons.home),
  AdRoute(route: '/videos',              label: 'Vidéos',                description: 'Section vidéos courtes',                  icon: Icons.play_circle),
  AdRoute(route: '/dating',              label: 'Rencontres',            description: 'Application de rencontres',               icon: Icons.favorite),
  AdRoute(route: '/list_live',           label: 'Lives',                 description: 'Lives en cours',                          icon: Icons.live_tv),
  AdRoute(route: '/create_live',         label: 'Créer un live',         description: 'Démarrer un live',                        icon: Icons.videocam),
  AdRoute(route: '/classemnent',         label: 'Classement',            description: 'Classement des créateurs',                icon: Icons.leaderboard),
  AdRoute(route: '/abonnement',          label: 'Abonnements',           description: 'Plans d\'abonnement premium',             icon: Icons.workspace_premium),
  AdRoute(route: '/coins/buy',           label: 'Acheter des pièces',    description: 'Boutique de pièces Afrolook',             icon: Icons.monetization_on),
  AdRoute(route: '/coins/transactions',  label: 'Mes transactions',      description: 'Historique des pièces',                   icon: Icons.receipt_long),
  AdRoute(route: '/creator/subscription',label: 'Abonnements créateurs', description: 'S\'abonner à des créateurs',              icon: Icons.star),
  AdRoute(route: '/mes_notifications',   label: 'Notifications',         description: 'Mes notifications',                      icon: Icons.notifications),
  AdRoute(route: '/gagner_point_infos',  label: 'Gagner des pièces',     description: 'Comment gagner des pièces',               icon: Icons.emoji_events),
  AdRoute(route: '/amis',               label: 'Mes amis',              description: 'Liste des amis et suggestions',           icon: Icons.people),
  AdRoute(route: '/list_users_chat',     label: 'Messages',              description: 'Messagerie privée',                       icon: Icons.chat_bubble),
  AdRoute(route: '/dating/list',         label: 'Profils Rencontres',    description: 'Explorer les profils de rencontres',      icon: Icons.search),
  AdRoute(route: '/dating/connections',  label: 'Mes connexions',        description: 'Mes matchs et connexions',                icon: Icons.handshake),
];

/// Action du bouton d'une publicité : ouvre le lien de l'annonceur, navigue en interne
/// (défi ou route), ou ouvre une URL externe. Un seul endroit pour tous les écrans.
class AdActions {
  AdActions._();

  /// Lien interne d'une publicité de DÉFI : `afrolook://defi/<id du post>`.
  static const defiScheme = 'afrolook://defi/';

  /// Lien interne vers une route de l'app : `afrolook://route/<route>`.
  static const routeScheme = 'afrolook://route/';

  static bool isDefiAd(Advertisement ad) =>
      ad.actionType == 'defi' || (ad.actionUrl ?? '').startsWith(defiScheme);

  static bool isRouteAd(Advertisement ad) =>
      ad.actionType == 'route' || (ad.actionUrl ?? '').startsWith(routeScheme);

  static Future<void> open(Advertisement ad) async {
    if (isDefiAd(ad)) {
      final raw = (ad.actionUrl ?? '').trim();
      final id = (ad.postId ?? '').isNotEmpty
          ? ad.postId!
          : (raw.startsWith(defiScheme) ? raw.substring(defiScheme.length) : '');
      if (id.isNotEmpty) await _openDefi(id);
      return;
    }
    if (isRouteAd(ad)) {
      final raw = (ad.actionUrl ?? '').trim();
      final route = raw.startsWith(routeScheme)
          ? '/${raw.substring(routeScheme.length)}'
          : '';
      if (route.isNotEmpty) _navigateToRoute(route);
      return;
    }
    final raw = (ad.actionUrl ?? '').trim();
    if (raw.isEmpty) return;
    final url = Uri.tryParse(raw);
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _openDefi(String postId) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('Posts').doc(postId).get();
      if (!snap.exists) return;
      final post = Post.fromJson({...snap.data()!, 'id': snap.id});
      NavigationService().navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => DetailsPost(post: post)));
    } catch (_) {/* l'ouverture ne doit jamais faire planter une publicité */}
  }

  static void _navigateToRoute(String route) {
    try {
      NavigationService().navigatorKey.currentState?.pushNamed(route);
    } catch (_) {}
  }
}
