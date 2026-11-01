import 'dart:async';

import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/paid_content_b2_api.dart';
import 'package:afrotok/services/media_cache_service.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:afrotok/widgets/music/music_overlay.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Un épisode d'une série : lecture (vidéo) ou ouverture du livre (PDF) par lien signé de 10 minutes, j'aime / je n'aime pas, partage, vues.
/// Le serveur décide de l'accès (épisode gratuit, série achetée, créateur ou équipe) : sans accès, il répond 403 `not_purchased`.
class EpisodePage extends StatefulWidget {
  const EpisodePage({super.key, required this.series, required this.episode, this.isOwner = false});

  final ContentPaie series;
  final SeriesEpisode episode;
  final bool isOwner;

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> with MusicSuspendMixin {
  late SeriesEpisode _ep = widget.episode;
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _loadingFile = true;
  String? _fileError;
  bool _reacting = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    setState(() {
      _loadingFile = true;
      _fileError = null;
    });
    try {
      // Fiche à jour (compteurs, ma réaction) : l'épisode de la liste peut dater de quelques minutes
      final fresh = await PaidSeriesApi.episode(_ep.id);
      if (fresh != null && mounted) setState(() => _ep = fresh);
      if (_ep.isEbook) {
        // Livre : le lien n'est demandé qu'au moment d'ouvrir (voir _openBook)
        if (mounted) setState(() => _loadingFile = false);
        unawaited(PaidSeriesApi.view(_ep.id));
        return;
      }
      final access = await PaidSeriesApi.access(_ep.id, fileKey: 'video');
      final controller = await MediaCacheService.videoController(access.url);
      await controller.initialize();
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        allowFullScreen: true,
        showOptions: false,
        placeholder: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
      if (!mounted) {
        chewie.dispose();
        controller.dispose();
        return;
      }
      setState(() {
        _video = controller;
        _chewie = chewie;
        _loadingFile = false;
      });
      unawaited(PaidSeriesApi.view(_ep.id));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fileError = PaidContentMessages.of(e);
        _loadingFile = false;
      });
    }
  }

  Future<void> _openBook() async {
    try {
      final access = await PaidSeriesApi.access(_ep.id, fileKey: 'pdf');
      final ok = await launchUrl(Uri.parse(access.url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Impossible d\'ouvrir le livre pour le moment.'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(PaidContentMessages.of(e)),
        action: SnackBarAction(label: tr('Réessayer'), onPressed: _openBook),
      ));
    }
  }

  /// J'aime / je n'aime pas : une réaction par personne ; la changer déplace le compteur. Affichage immédiat, annulé si le serveur refuse.
  Future<void> _react(String kind) async {
    if (_reacting) return;
    final before = _ep;
    final same = before.myReaction == kind;
    var likes = before.likes;
    var dislikes = before.dislikes;
    if (before.myReaction == 'like') likes--;
    if (before.myReaction == 'dislike') dislikes--;
    if (!same) {
      if (kind == 'like') likes++;
      if (kind == 'dislike') dislikes++;
    }
    setState(() {
      _reacting = true;
      _ep = before.copyWith(likes: likes < 0 ? 0 : likes, dislikes: dislikes < 0 ? 0 : dislikes, myReaction: same ? null : kind, clearReaction: same);
    });
    try {
      if (same) {
        await PaidSeriesApi.unreact(_ep.id);
      } else {
        await PaidSeriesApi.react(_ep.id, kind);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _ep = before);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(PaidContentMessages.of(e)),
        action: SnackBarAction(label: tr('Réessayer'), onPressed: () => _react(kind)),
      ));
    } finally {
      if (mounted) setState(() => _reacting = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final link = 'https://afrolookmedia.com/share/contenu/${widget.series.id}';
      await Share.share('🛍️ ${widget.series.title} — ${tr('Épisode {n}', {'n': _ep.number})}\n\n$link', subject: widget.series.title);
      final r = await PaidSeriesApi.share(_ep.id);
      if (mounted) setState(() => _ep = _ep.copyWith(shares: r.sharesCount));
    } catch (e) {
      // Le partage lui-même a eu lieu : seul le compteur du serveur n'a pas pu être mis à jour (sans message, il sera recompté plus tard)
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(tr('Épisode {n}', {'n': _ep.number}), style: TextStyle(color: colors.textPrimary, fontSize: 16)),
      ),
      body: ListView(
        children: [
          _buildPlayer(colors),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.series.title, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(_ep.title, style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                if (_ep.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_ep.description, style: TextStyle(color: colors.textPrimary, fontSize: 13, height: 1.4)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _ActionChip(
                  icon: _ep.myReaction == 'like' ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                  label: '${_ep.likes}',
                  active: _ep.myReaction == 'like',
                  onTap: () => _react('like'),
                ),
                _ActionChip(
                  icon: _ep.myReaction == 'dislike' ? Icons.thumb_down_alt : Icons.thumb_down_alt_outlined,
                  label: '${_ep.dislikes}',
                  active: _ep.myReaction == 'dislike',
                  onTap: () => _react('dislike'),
                ),
                _ActionChip(icon: Icons.share_outlined, label: '${_ep.shares}', onTap: _share),
                const Spacer(),
                Icon(Icons.visibility_outlined, size: 16, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text('${_ep.views}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(AppColors colors) {
    if (_loadingFile) {
      return const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()));
    }
    if (_fileError != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_fileError!, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _loadFile, child: Text(tr('Réessayer'))),
              ],
            ),
          ),
        ),
      );
    }
    if (_ep.isEbook) {
      return Container(
        height: 200,
        color: colors.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded, size: 48, color: colors.primary),
              if (_ep.pageCount > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('{n} pages', {'n': _ep.pageCount}), style: TextStyle(color: colors.textSecondary))),
              const SizedBox(height: 10),
              ElevatedButton.icon(onPressed: _openBook, icon: const Icon(Icons.open_in_new), label: Text(tr('Ouvrir le livre'))),
            ],
          ),
        ),
      );
    }
    final chewie = _chewie;
    if (chewie == null || _video == null) return const SizedBox.shrink();
    return AspectRatio(aspectRatio: _video!.value.aspectRatio, child: Chewie(controller: chewie));
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = active ? colors.primary : colors.textSecondary;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
