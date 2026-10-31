import '../post_video_format_tel_details.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:flutter/material.dart';

import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import '../postDetails.dart';
import '../user/otherUser/otherUser.dart';

/// File de modération (règle App Store 1.2) : signalements de publications et blocages
/// d'utilisateurs, à traiter sous 24 h — retirer le contenu, suspendre l'auteur depuis son
/// profil, puis classer. Tout passe par l'API (`/admin/moderation/*`).
class ModerationReportsPage extends StatefulWidget {
  const ModerationReportsPage({super.key});

  @override
  State<ModerationReportsPage> createState() => _ModerationReportsPageState();
}

class _ModerationReportsPageState extends State<ModerationReportsPage> {
  bool _showResolved = false; // « Traités » = journal des décisions de l'équipe
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _blocks = [];
  List<Map<String, dynamic>> _decisions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(Object? v) => (v is List ? v : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_showResolved) {
        final d = await RegieApi.getList('/admin/moderation/decisions', query: {'limit': 100});
        if (!mounted) return;
        setState(() {
          _decisions = d;
          _loading = false;
        });
      } else {
        final q = await RegieApi.getMap('/admin/moderation/queue');
        if (!mounted) return;
        setState(() {
          _posts = _rows(q['posts']);
          _blocks = _rows(q['blocks']);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = RegieApi.err(e);
          _loading = false;
        });
      }
    }
  }

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
            onPressed: () {
              setState(() => _showResolved = !_showResolved);
              _load();
            },
            child: Text(_showResolved ? 'À traiter' : 'Traités'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: TextStyle(color: colors.danger), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                  ]),
                )
              : _list(colors),
    );
  }

  Widget _list(AppColors colors) {
    final empty = _showResolved ? _decisions.isEmpty : (_posts.isEmpty && _blocks.isEmpty);
    if (empty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _showResolved ? 'Aucune décision enregistrée.' : 'Aucun signalement en attente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }
    final items = _showResolved
        ? [for (final d in _decisions) _decisionCard(colors, d)]
        : [for (final p in _posts) _reportCard(colors, p), for (final b in _blocks) _blockCard(colors, b)];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  BoxDecoration _box(AppColors colors, {bool alert = false}) => BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alert ? colors.danger : colors.border),
      );

  Widget _decisionCard(AppColors colors, Map<String, dynamic> d) {
    final at = DateTime.tryParse('${d['created_at']}')?.toLocal();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(colors),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          switch ('${d['action']}') {
            'remove' => 'Publication retirée',
            'restore' => 'Publication rétablie',
            'dismiss' => 'Classé sans suite',
            'suspend_user' => 'Compte suspendu',
            'restore_user' => 'Compte rétabli',
            _ => '${d['action']}',
          },
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        ),
        if (at != null) Text('Le ${_fmt(at)}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        if ('${d['reason'] ?? ''}'.isNotEmpty) Text('Motif : ${d['reason']}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
      ]),
    );
  }

  Widget _blockCard(AppColors colors, Map<String, dynamic> b) {
    final at = DateTime.tryParse('${b['created_at']}')?.toLocal();
    final target = '${b['blocked_id'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(colors),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.block, color: colors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('@${b['blocker'] ?? '?'} a bloqué @${b['blocked'] ?? '?'}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold))),
        ]),
        if (at != null) Text('Le ${_fmt(at)}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        if (target.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _openProfile(target),
            icon: const Icon(Icons.person_off_outlined, size: 16),
            label: const Text('Profil (suspendre)'),
          ),
      ]),
    );
  }

  Widget _reportCard(AppColors colors, Map<String, dynamic> r) {
    final postId = '${r['post_id']}';
    final authorId = '${r['author_id'] ?? ''}';
    final first = DateTime.tryParse('${r['first_at']}')?.toLocal();
    final due = DateTime.tryParse('${r['due_at']}')?.toLocal();
    final overdue = r['overdue'] == true;
    final types = (r['types'] as List? ?? const []).join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(colors, alert: overdue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.flag, color: colors.danger, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('${r['reports']} signalement(s) sur une publication', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 6),
          if ('${r['excerpt'] ?? ''}'.isNotEmpty) Text('« ${r['excerpt']} »', style: TextStyle(color: colors.textPrimary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${first != null ? 'Premier signalement le ${_fmt(first)}' : ''}'
            '${types.isNotEmpty ? ' • motif : $types' : ''}'
            '${overdue ? ' • délai de 24 h dépassé' : due != null ? ' • à traiter avant le ${_fmt(due)}' : ''}',
            style: TextStyle(color: overdue ? colors.danger : colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _openPost(postId),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Voir la publication'),
            ),
            OutlinedButton.icon(
              onPressed: () => _removePost(postId),
              style: OutlinedButton.styleFrom(foregroundColor: colors.danger),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Retirer le contenu'),
            ),
            if (authorId.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _openProfile(authorId),
                icon: const Icon(Icons.person_off_outlined, size: 16),
                label: const Text('Profil (suspendre)'),
              ),
            ElevatedButton.icon(
              onPressed: () => _decide(postId, 'dismiss'),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Classer sans suite'),
            ),
          ]),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _decide(String postId, String action, {String? reason}) async {
    try {
      await RegieApi.post('/admin/moderation/posts/$postId', body: {'action': action, if (reason != null) 'reason': reason});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'remove' ? 'Contenu retiré.' : 'Signalement traité.')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RegieApi.err(e))));
    }
  }

  Future<void> _openPost(String postId) async {
    try {
      final data = await RegieApi.getMap('/posts/$postId');
      if (!mounted) return;
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication introuvable.')));
        return;
      }
      final post = postFromApi(data);
      Navigator.push(context, MaterialPageRoute(builder: (_) => post.dataType == PostDataType.VIDEO.name ? PostDetailsVideoFormatTel(initialPost: post, isIn: false) : DetailsPost(post: post)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RegieApi.err(e))));
    }
  }

  Future<void> _openProfile(String userId) async {
    try {
      final j = await UsersApi.publicProfile(userId);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserPage(otherUser: userFromApi(j))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RegieApi.err(e))));
    }
  }

  Future<void> _removePost(String postId) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer ce contenu ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('La publication sera masquée et le signalement traité.'),
          const SizedBox(height: 8),
          TextField(controller: ctl, maxLength: 200, decoration: const InputDecoration(labelText: 'Motif (obligatoire)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final reason = ctl.text.trim();
    if (reason.length < 3) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le motif est obligatoire.')));
      return;
    }
    await _decide(postId, 'remove', reason: reason);
  }
}
