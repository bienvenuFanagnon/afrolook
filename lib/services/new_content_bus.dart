import 'dart:async';

import 'package:afrotok/services/read_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ads/ad_config.dart';
import '../ads/ad_gate.dart';
import '../ads/admob_service.dart';
import '../models/model_data.dart';
import '../providers/authProvider.dart';
import 'nav_cache_service.dart';

/// Après une publication (post, post de canal, chronique) :
///  - retour AUTOMATIQUE à l'accueil (la page de publication ne reste plus ouverte) ;
///  - le contenu qu'on vient de publier apparaît EN TÊTE du fil, et le fil remonte tout en haut, même si on était au milieu avant d'aller publier.
/// Point d'entrée unique : [onPublished] est appelé par addPointsForAction(UserAction.post), déjà exécuté à la fin de chaque formulaire de publication.
class NewContentBus {
  NewContentBus._();
  static final NewContentBus instance = NewContentBus._();

  final _posts = StreamController<Post>.broadcast();
  final _homeRequests = StreamController<void>.broadcast();
  final _chroniques = StreamController<void>.broadcast();
  DateTime? _chroniqueAt;

  /// Le dernier post publié par la personne (à placer en tête du fil).
  Stream<Post> get newPosts => _posts.stream;

  /// L'accueil doit passer au premier onglet et remonter en haut.
  Stream<void> get homeRequests => _homeRequests.stream;

  /// Une chronique vient d'être publiée (la barre des chroniques doit se rafraîchir).
  Stream<void> get chroniquePublished => _chroniques.stream;

  /// Une publication (post, post de canal…) vient de réussir.
  void onPublished() {
    // une chronique vient d'être annoncée juste avant : elle a déjà géré son retour
    final c = _chroniqueAt;
    if (c != null && DateTime.now().difference(c) < const Duration(seconds: 8)) return;
    _goHome();
    unawaited(_showLatestOwnPost());
  }

  /// Une chronique vient d'être publiée.
  void onChroniquePublished() {
    _chroniqueAt = DateTime.now();
    _goHome();
    _chroniques.add(null);
  }

  void _goHome() {
    // laisse d'abord le formulaire fermer ses propres boîtes de dialogue (chargement…), puis ferme ce qui reste ouvert au-dessus de l'accueil
    Future.delayed(const Duration(milliseconds: 700), () {
      NavigationCacheService().navigatorKey.currentState?.popUntil((route) => route.isFirst);
      _homeRequests.add(null);
      Future.delayed(const Duration(milliseconds: 1500), _maybeInterstitialAfterPublish);
    });
  }

  /// Une pub plein écran après une publication réussie : moment naturel (l'action est terminée), UNE par jour au plus, jamais pour un Gold ni si les
  /// pubs plein écran sont coupées. Le retour à l'accueil et le nouveau post en tête du fil sont déjà faits.
  Future<void> _maybeInterstitialAfterPublish() async {
    try {
      final ctx = NavigationCacheService().navigatorKey.currentContext;
      if (ctx == null) return;
      final user = Provider.of<UserAuthProvider>(ctx, listen: false).loginUserData;
      final cfg = AdConfig.current;
      if (!AdConfig.isMobile || !cfg.enabled || !cfg.interstitialEnabled || !AdGate.canShowType(user, 'interstitial')) return;
      final sp = await SharedPreferences.getInstance();
      final n = DateTime.now();
      final key = 'pub_inter_${n.year}-${n.month}-${n.day}';
      if ((sp.getInt(key) ?? 0) >= 1) return;
      if (await AdmobService.showInterstitialNow()) await sp.setInt(key, 1);
    } catch (_) {}
  }

  Future<void> _showLatestOwnPost() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('Posts')
          .where('user_id', isEqualTo: uid)
          .orderBy('created_at', descending: true)
          .limit(1)
          .getM('new_content_bus.dart:latest');
      if (snap.docs.isEmpty) return;
      final post = Post.fromJson(snap.docs.first.data())..id = snap.docs.first.id;
      // seulement un post tout juste publié (jamais un ancien post si la publication n'a pas créé de post)
      var created = post.createdAt ?? 0;
      if (created > 100000000000000) created ~/= 1000; // microsecondes → millisecondes
      if (DateTime.now().millisecondsSinceEpoch - created > 3 * 60 * 1000) return;
      _posts.add(post);
    } catch (_) {}
  }
}
