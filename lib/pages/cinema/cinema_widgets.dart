import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';

/// Éléments communs de Cartoon Cinéma (21/11/2026) : étiquettes, affiches, impressions, formats de nombres et de durées.

/// Les six impressions, dans l'ordre d'affichage : icône, couleur, libellé.
const List<(String, IconData, Color, String)> kCinemaReactions = [
  ('love', Icons.favorite_rounded, Color(0xFFFF4D6A), "J'aime"),
  ('joy', Icons.sentiment_very_satisfied_rounded, Color(0xFFF2A100), 'Joie'),
  ('laugh', Icons.emoji_emotions_rounded, Color(0xFFF2A100), 'Rire'),
  ('wow', Icons.auto_awesome_rounded, Color(0xFF7B61FF), 'Waouh'),
  ('sad', Icons.sentiment_dissatisfied_rounded, Color(0xFF3D8BFF), 'Triste'),
  ('angry', Icons.mood_bad_rounded, Color(0xFFE5483D), 'Colère'),
];

/// 1 234 -> « 1,2 k » ; 1 500 000 -> « 1,5 M ».
String cinemaCount(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} k';
  return '${n.toInt()}';
}

/// 1320 s -> « 22 min » ; 5520 s -> « 1 h 32 ».
String cinemaDuration(int seconds) {
  if (seconds <= 0) return '';
  final m = (seconds / 60).round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
}

/// 412 s -> « 06:52 ».
String cinemaClock(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Étiquette courte (Gratuit, Gold, Nouveau, 10 s gratuites…). Jaune toujours en fond, texte noir.
class CinemaTag extends StatelessWidget {
  const CinemaTag(this.text, {super.key, this.kind = 'dark', this.icon});

  final String text;
  final String kind; // free, gold, new, dark, preview
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (kind) {
      'free' => (const Color(0xFF158246), Colors.white),
      'gold' => (const Color(0xFFFFD400), const Color(0xFF121212)),
      'new' => (const Color(0xFFD92D3A), Colors.white),
      'preview' => (const Color(0xFF121212), const Color(0xFFFFD400)),
      _ => (Colors.black.withValues(alpha: .55), Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 3)],
        Text(text.toUpperCase(), style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
      ]),
    );
  }
}

/// Étiquette d'accès d'un épisode : Gratuit, ou « 10 s gratuites · Gold ».
Widget cinemaAccessTag(BuildContext context, Map<String, dynamic> ep) {
  if (ep['access'] == 'free') return CinemaTag(context.tr('Gratuit'), kind: 'free');
  return CinemaTag(context.tr('{a} s gratuites · Gold', {'a': ep['preview_seconds'] ?? 10}), kind: 'preview', icon: Icons.workspace_premium_rounded);
}

/// Image réseau avec un fond neutre pendant le chargement et en cas d'erreur.
class CinemaImage extends StatelessWidget {
  const CinemaImage(this.url, {super.key, this.radius = 12, this.fit = BoxFit.cover, this.icon = Icons.movie_rounded});

  final String? url;
  final double radius;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ph = Container(color: c.surfaceVariant, alignment: Alignment.center, child: Icon(icon, color: c.textSecondary, size: 28));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (url == null || url!.isEmpty) ? ph : CachedNetworkImage(imageUrl: url!, fit: fit, placeholder: (_, __) => ph, errorWidget: (_, __, ___) => ph),
    );
  }
}

/// Affiche verticale d'une série ou d'un film, avec son étiquette.
class CinemaPoster extends StatelessWidget {
  const CinemaPoster({super.key, required this.title, required this.onTap});

  final Map<String, dynamic> title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final film = title['kind'] == 'film';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 104,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 150, child: Stack(fit: StackFit.expand, children: [
            CinemaImage(title['poster_url'] as String? ?? title['banner_url'] as String?),
            Positioned(top: 6, left: 6, child: CinemaTag(context.tr(film ? 'Film' : 'Série'))),
          ])),
          const SizedBox(height: 5),
          Text('${title['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
          if ((title['genre'] as String?)?.isNotEmpty == true) Text('${title['genre']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
        ]),
      ),
    );
  }
}

/// Vignette horizontale d'un épisode (continuer, pas encore vus, gratuits), avec la barre de progression.
class CinemaEpisodeThumb extends StatelessWidget {
  const CinemaEpisodeThumb({super.key, required this.ep, required this.onTap});

  final Map<String, dynamic> ep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dur = (ep['duration_sec'] as num?)?.toInt() ?? 0;
    final pos = (ep['my_position_sec'] as num?)?.toInt() ?? 0;
    final ratio = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 178,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 100, child: Stack(fit: StackFit.expand, children: [
            CinemaImage(ep['thumb_url'] as String? ?? ep['banner_url'] as String?),
            Positioned(top: 6, left: 6, child: ep['seen'] == true ? cinemaAccessTag(context, ep) : CinemaTag(context.tr('Nouveau'), kind: 'new')),
            if (ratio > 0)
              Positioned(left: 8, right: 8, bottom: 8, child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(value: ratio, minHeight: 3, backgroundColor: Colors.white.withValues(alpha: .35), color: const Color(0xFFFFD400)),
              )),
          ])),
          const SizedBox(height: 5),
          Text(
            [if ((ep['title_name'] as String?)?.isNotEmpty == true) ep['title_name'], context.tr('Ép. {a}', {'a': ep['number']})].join(' · '),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text('${ep['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
        ]),
      ),
    );
  }
}

/// Titre de rangée (« Pas encore vus », « Séries »…).
class CinemaRowTitle extends StatelessWidget {
  const CinemaRowTitle(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800))),
        if (trailing != null) Text(trailing!, style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Logo du cinéma (fond noir, clap jaune).
class CinemaLogo extends StatelessWidget {
  const CinemaLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(size * .3)),
        child: Icon(Icons.movie_filter_rounded, color: const Color(0xFFFFD400), size: size * .58),
      );
}
