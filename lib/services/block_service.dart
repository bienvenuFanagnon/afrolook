import 'package:afrotok/services/api/users_api.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Utilisateurs bloqués par l'utilisateur connecté (règle App Store 1.2).
///
/// La liste vient de l'API (`GET /v1/blocks`), chargée au démarrage puis tenue à jour localement à chaque blocage / déblocage :
/// dès qu'un blocage est ajouté, les widgets qui écoutent ce service masquent immédiatement les contenus de la personne bloquée.
/// Bloquer met fin à l'amitié et annule les invitations en attente (règle du serveur).
class BlockService extends ChangeNotifier {
  BlockService._();
  static final BlockService instance = BlockService._();

  final Set<String> _blocked = {};
  String? _uid;

  bool isBlocked(String? userId) => userId != null && _blocked.contains(userId);

  /// À appeler une fois l'utilisateur connecté (sans effet si déjà démarré pour ce compte).
  void start() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == _uid) return;
    _uid = uid;
    _blocked.clear();
    refresh();
  }

  /// Recharge la liste depuis l'API (en cas d'échec : la liste actuelle est conservée).
  Future<void> refresh() async {
    try {
      final rows = await UsersApi.blocks();
      _blocked
        ..clear()
        ..addAll(rows.map((r) => r['id']).whereType<String>());
      notifyListeners();
    } catch (e) {
      debugPrint('BlockService: $e');
      _uid = null; // sera retenté au prochain start()
    }
  }

  Future<void> block(String userId, {String? postId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || userId.isEmpty || userId == uid) return;
    await UsersApi.block(userId, source: postId != null ? 'post' : 'profile', postId: postId);
    _blocked.add(userId);
    notifyListeners();
  }

  Future<void> unblock(String userId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await UsersApi.unblock(userId);
    _blocked.remove(userId);
    notifyListeners();
  }
}

/// Demande confirmation puis bloque l'auteur. Retourne true si le blocage a été fait.
Future<bool> confirmAndBlockUser(
  BuildContext context, {
  required String userId,
  String? pseudo,
  String? postId,
}) async {
  final name = (pseudo == null || pseudo.isEmpty) ? 'cet utilisateur' : '@$pseudo';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Bloquer $name ?'),
      content: Text(
        "Ses publications disparaîtront immédiatement de ton fil et il ne pourra plus t'écrire. "
        "Notre équipe de modération sera prévenue.",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Bloquer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await BlockService.instance.block(userId, postId: postId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name est bloqué. Ses contenus ne s\'afficheront plus.')),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le blocage n'a pas pu être enregistré. Réessaie.")),
      );
    }
    return false;
  }
}
