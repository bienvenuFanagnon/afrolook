import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentForm.dart' show ContentFormScreen;
import 'package:afrotok/pages/contenuPayant/episode_page.dart';
import 'package:afrotok/services/api/paid_content_b2_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Liste des épisodes d'une série (`GET /paid-contents/{série}/episodes`). L'achat se fait sur la SÉRIE : un épisode gratuit est ouvert à tous,
/// les autres à qui a acheté la série (le serveur dit, épisode par épisode, si j'y ai accès). Le créateur peut ajouter et supprimer des épisodes.
class SeriesEpisodesSection extends StatefulWidget {
  const SeriesEpisodesSection({super.key, required this.series, required this.isOwner, this.onNeedPurchase});

  final ContentPaie series;

  /// Créateur de la série ou administrateur : peut ajouter / supprimer des épisodes.
  final bool isOwner;

  /// Appelé quand on touche un épisode verrouillé (par exemple pour montrer le bouton d'achat).
  final VoidCallback? onNeedPurchase;

  @override
  State<SeriesEpisodesSection> createState() => _SeriesEpisodesSectionState();
}

class _SeriesEpisodesSectionState extends State<SeriesEpisodesSection> {
  List<SeriesEpisode> _episodes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.series.id;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await PaidSeriesApi.episodes(id);
      if (!mounted) return;
      setState(() {
        _episodes = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = PaidContentMessages.of(e);
        _loading = false;
      });
    }
  }

  Future<void> _open(SeriesEpisode ep) async {
    if (!ep.isFree && !ep.hasAccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Achète cette série pour regarder cet épisode.'))));
      widget.onNeedPurchase?.call();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EpisodePage(series: widget.series, episode: ep, isOwner: widget.isOwner)));
    if (mounted) _load(); // compteurs (vues, j'aime) à jour au retour
  }

  Future<void> _add() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContentFormScreen(isEpisode: true, seriesId: widget.series.id, seriesType: widget.series.contentType)),
    );
    if (mounted) _load();
  }

  Future<void> _delete(SeriesEpisode ep) async {
    final colors = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(tr('Supprimer cet épisode ?'), style: TextStyle(color: colors.textPrimary)),
        content: Text(tr('L\'épisode {n} sera supprimé définitivement. Son numéro sera de nouveau libre.', {'n': ep.number}), style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Annuler'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Supprimer'), style: TextStyle(color: colors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PaidSeriesApi.delete(ep.id);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(PaidContentMessages.of(e)),
        action: e is ApiException && e.isNetwork ? SnackBarAction(label: tr('Réessayer'), onPressed: () => _delete(ep)) : null,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _loading ? tr('ÉPISODES') : tr('ÉPISODES ({n})', {'n': _episodes.length}),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: colors.textSecondary),
                ),
              ),
              if (widget.isOwner)
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(tr('Ajouter un épisode'), style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                TextButton(onPressed: _load, child: Text(tr('Réessayer'))),
              ],
            ),
          )
        else if (_episodes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(tr('Aucun épisode pour l\'instant.'), style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          )
        else
          for (final ep in _episodes)
            EpisodeRow(
              episode: ep,
              colors: colors,
              onTap: () => _open(ep),
              onDelete: widget.isOwner ? () => _delete(ep) : null,
            ),
      ],
    );
  }
}

/// Une ligne d'épisode : numéro, miniature, titre, « Gratuit » ou cadenas, vues et j'aime.
class EpisodeRow extends StatelessWidget {
  const EpisodeRow({super.key, required this.episode, required this.colors, required this.onTap, this.onDelete});

  final SeriesEpisode episode;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final locked = !episode.isFree && !episode.hasAccess;
    const green = Color(0xFF25D366);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.divider))),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: locked ? colors.surface : green.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: locked ? colors.divider : green.withOpacity(0.4)),
              ),
              child: Center(child: Text('E${episode.number}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: locked ? colors.textSecondary : green))),
            ),
            const SizedBox(width: 10),
            Container(
              width: 52,
              height: 38,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(6)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (episode.thumbnailUrl.isNotEmpty)
                    Image.network(episode.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🎬')))
                  else
                    Center(child: Text(episode.isEbook ? '📖' : '🎬', style: const TextStyle(fontSize: 18))),
                  if (locked)
                    Container(
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.lock_outline, color: Colors.white, size: 14),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (episode.isFree)
                        Text(tr('Gratuit'), style: const TextStyle(fontSize: 10, color: green, fontWeight: FontWeight.w700))
                      else if (locked)
                        Text(tr('Série payante'), style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                      if (episode.isFree || locked) const SizedBox(width: 8),
                      Icon(Icons.visibility_outlined, size: 11, color: colors.textSecondary),
                      const SizedBox(width: 2),
                      Text('${episode.views}', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                      const SizedBox(width: 8),
                      Icon(Icons.thumb_up_alt_outlined, size: 11, color: colors.textSecondary),
                      const SizedBox(width: 2),
                      Text('${episode.likes}', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline, size: 18, color: colors.textSecondary),
                tooltip: tr('Supprimer'),
                onPressed: onDelete,
              ),
            if (locked) const Icon(Icons.lock_outline, color: Colors.grey, size: 20) else const Icon(Icons.play_circle_outline, color: green, size: 26),
          ],
        ),
      ),
    );
  }
}
