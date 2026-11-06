import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../services/api/posts_api.dart';
import '../../theme/app_colors.dart';
import '../postDetails.dart';

/// Les réponses en vidéo faites à un post : on retrouve ainsi toute la conversation à partir du post d'origine.
class ReplyVideosPage extends StatefulWidget {
  const ReplyVideosPage({super.key, required this.postId, this.loader});

  final String postId;

  /// Remplaçable dans les tests.
  final Future<List<Post>> Function(String postId)? loader;

  @override
  State<ReplyVideosPage> createState() => _ReplyVideosPageState();
}

class _ReplyVideosPageState extends State<ReplyVideosPage> {
  List<Post>? _posts;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final l = await (widget.loader ?? PostsApi.replies)(widget.postId);
      if (mounted) setState(() => _posts = l);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text(context.tr('Réponses en vidéo'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: _error
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(context.tr('Impossible de charger les réponses.'), style: TextStyle(color: c.textSecondary)),
                TextButton(key: const ValueKey('replies_retry'), onPressed: _load, child: Text(context.tr('Réessayer'))),
              ]),
            )
          : _posts == null
              ? const Center(child: CircularProgressIndicator())
              : _posts!.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(context.tr('Personne n\'a encore répondu en vidéo.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 15))))
                  : ListView.separated(
                      key: const ValueKey('replies_list'),
                      padding: const EdgeInsets.all(16),
                      itemCount: _posts!.length,
                      separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
                      itemBuilder: (_, i) {
                        final p = _posts![i];
                        final who = (p.user?.pseudo ?? '').isEmpty ? context.tr('Quelqu\'un') : '@${p.user!.pseudo}';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          leading: CircleAvatar(backgroundColor: c.accent, child: Icon(Icons.play_arrow_rounded, color: c.onAccent)),
                          title: Text(who, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                          subtitle: (p.description ?? '').trim().isEmpty ? null : Text(p.description!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary)),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsPost(post: p))),
                        );
                      },
                    ),
    );
  }
}
