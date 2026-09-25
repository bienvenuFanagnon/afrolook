import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Utilisateurs bloqués par l'utilisateur connecté (règle App Store 1.2).
///
/// Même format que le chat : `BlockedUsers/<bloqueur>_<bloqué>`. La liste est écoutée en
/// temps réel : dès qu'un blocage est ajouté, les widgets qui écoutent ce service masquent
/// immédiatement les contenus de la personne bloquée. La Cloud Function onUserBlocked prévient
/// l'équipe de modération.
class BlockService extends ChangeNotifier {
  BlockService._();
  static final BlockService instance = BlockService._();

  final Set<String> _blocked = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;

  bool isBlocked(String? userId) => userId != null && _blocked.contains(userId);

  /// À appeler une fois l'utilisateur connecté (sans effet si déjà démarré pour ce compte).
  void start() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _blocked.clear();
    _sub = FirebaseFirestore.instance
        .collection('BlockedUsers')
        .where('blockedBy', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      _blocked
        ..clear()
        ..addAll(snap.docs.map((d) => d.data()['blockedUser']).whereType<String>());
      notifyListeners();
    }, onError: (Object e) => debugPrint('BlockService: $e'));
  }

  Future<void> block(String userId, {String? postId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || userId.isEmpty || userId == uid) return;
    _blocked.add(userId);
    notifyListeners();
    await FirebaseFirestore.instance.collection('BlockedUsers').doc('${uid}_$userId').set({
      'blockedBy': uid,
      'blockedUser': userId,
      'chatId': '',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'source': postId != null ? 'post' : 'profile',
      if (postId != null) 'postId': postId,
    });
  }

  Future<void> unblock(String userId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _blocked.remove(userId);
    notifyListeners();
    await FirebaseFirestore.instance.collection('BlockedUsers').doc('${uid}_$userId').delete();
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
