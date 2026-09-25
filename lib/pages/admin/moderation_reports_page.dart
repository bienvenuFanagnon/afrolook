import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import '../postDetails.dart';
import '../user/otherUser/otherUser.dart';

/// File de modération (règle App Store 1.2) : signalements de publications et blocages
/// d'utilisateurs, à traiter sous 24 h — supprimer le contenu, suspendre l'auteur depuis son
/// profil, puis marquer comme traité.
class ModerationReportsPage extends StatefulWidget {
  const ModerationReportsPage({super.key});

  @override
  State<ModerationReportsPage> createState() => _ModerationReportsPageState();
}

class _ModerationReportsPageState extends State<ModerationReportsPage> {
  final _db = FirebaseFirestore.instance;
  bool _showResolved = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => _db
      .collection('ModerationReports')
      .where('status', isEqualTo: _showResolved ? 'resolved' : 'pending')
      .limit(200)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Modération', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: colors.surface,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showResolved = !_showResolved),
            child: Text(_showResolved ? 'À traiter' : 'Traités'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Impossible de charger la file de modération.',
                style: TextStyle(color: colors.textSecondary)));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs.toList()
            ..sort((a, b) => ((b.data()['createdAt'] ?? 0) as num).compareTo((a.data()['createdAt'] ?? 0) as num));
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _showResolved ? 'Aucun signalement traité.' : '✅ Aucun signalement en attente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _reportCard(colors, docs[i]),
          );
        },
      ),
    );
  }

  Widget _reportCard(AppColors colors, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final r = doc.data();
    final isBlock = r['type'] == 'user_block';
    final reporter = '@${r['reporterPseudo'] ?? '?'}';
    final target = '@${r['targetPseudo'] ?? '?'}';
    final createdAt = DateTime.fromMillisecondsSinceEpoch(((r['createdAt'] ?? 0) as num).toInt());
    final dueAt = DateTime.fromMillisecondsSinceEpoch(((r['dueAt'] ?? 0) as num).toInt());
    final overdue = r['status'] == 'pending' && DateTime.now().isAfter(dueAt);
    final postId = r['postId'] as String?;
    final targetUserId = r['targetUserId'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: overdue ? colors.danger : colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isBlock ? Icons.block : Icons.flag, color: colors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBlock ? '$reporter a bloqué $target' : '$reporter a signalé une publication de $target',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Le ${_fmt(createdAt)}'
            '${r['reason'] != null ? ' • motif : ${r['reason']}' : ''}'
            '${overdue ? ' • ⚠️ délai de 24 h dépassé' : r['status'] == 'pending' ? ' • à traiter avant le ${_fmt(dueAt)}' : ''}',
            style: TextStyle(color: overdue ? colors.danger : colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (postId != null) ...[
                OutlinedButton.icon(
                  onPressed: () => _openPost(postId),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Voir la publication'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deletePost(postId, doc.reference),
                  style: OutlinedButton.styleFrom(foregroundColor: colors.danger),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Supprimer le contenu'),
                ),
              ],
              if (targetUserId != null)
                OutlinedButton.icon(
                  onPressed: () => _openProfile(targetUserId),
                  icon: const Icon(Icons.person_off_outlined, size: 16),
                  label: const Text('Profil (suspendre)'),
                ),
              if (r['status'] == 'pending')
                ElevatedButton.icon(
                  onPressed: () => _resolve(doc.reference, 'traité'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Marquer traité'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _resolve(DocumentReference ref, String action) async {
    await ref.update({
      'status': 'resolved',
      'resolvedAt': DateTime.now().millisecondsSinceEpoch,
      'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
      'action': action,
    });
  }

  Future<void> _openPost(String postId) async {
    final doc = await _db.collection('Posts').doc(postId).get();
    if (!mounted) return;
    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication déjà supprimée.')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsPost(post: Post.fromJson(doc.data()!))));
  }

  Future<void> _openProfile(String userId) async {
    final doc = await _db.collection('Users').doc(userId).get();
    if (!mounted) return;
    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte introuvable.')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserPage(otherUser: UserData.fromJson(doc.data()!))));
  }

  Future<void> _deletePost(String postId, DocumentReference reportRef) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce contenu ?'),
        content: const Text('La publication sera supprimée définitivement et le signalement marqué comme traité.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.collection('Posts').doc(postId).delete();
      await _resolve(reportRef, 'contenu supprimé');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contenu supprimé.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suppression impossible, réessaie.')));
      }
    }
  }
}
