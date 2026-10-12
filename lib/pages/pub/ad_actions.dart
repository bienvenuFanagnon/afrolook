import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../services/navigation_service.dart';
import '../postDetails.dart';

/// Action du bouton d'une publicité : ouvre le lien de l'annonceur, ou — pour la publicité d'un DÉFI — le DÉFI lui-même, dans
/// l'application, où la personne peut participer. Un seul endroit pour tous les écrans qui affichent des publicités.
class AdActions {
  AdActions._();

  /// Lien interne d'une publicité de DÉFI : `afrolook://defi/<id du post>`.
  static const defiScheme = 'afrolook://defi/';

  static bool isDefiAd(Advertisement ad) => ad.actionType == 'defi' || (ad.actionUrl ?? '').startsWith(defiScheme);

  static Future<void> open(Advertisement ad) async {
    final raw = (ad.actionUrl ?? '').trim();
    if (isDefiAd(ad)) {
      final id = (ad.postId ?? '').isNotEmpty ? ad.postId! : (raw.startsWith(defiScheme) ? raw.substring(defiScheme.length) : '');
      if (id.isNotEmpty) await _openDefi(id);
      return;
    }
    if (raw.isEmpty) return;
    final url = Uri.tryParse(raw);
    if (url != null && await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  static Future<void> _openDefi(String postId) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('Posts').doc(postId).get();
      if (!snap.exists) return;
      final post = Post.fromJson({...snap.data()!, 'id': snap.id});
      NavigationService().navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => DetailsPost(post: post)));
    } catch (_) {/* l'ouverture ne doit jamais faire planter une publicité */}
  }
}
