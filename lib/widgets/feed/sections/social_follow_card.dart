import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/tr.dart';
import '../../../theme/app_colors.dart';

/// Où le widget est affiché : carte en 1re position, bandeau entre deux posts,
/// ou carte de fin de feed.
enum SocialFollowVariant { top, slim, end }

/// Invitation à suivre Afrolook sur Facebook et TikTok.
///
/// Le clic ouvre la vraie page. Aucune vérification n'est possible côté réseau :
/// on affiche simplement « prise en compte en cours » puis le widget se masque 1 h.
class SocialFollowCard extends StatefulWidget {
  final SocialFollowVariant variant;
  const SocialFollowCard({Key? key, required this.variant}) : super(key: key);

  static const facebookUrl = 'https://www.facebook.com/share/18tutZomcK/';
  static const tiktokUrl = 'https://www.tiktok.com/@afrotechstudio';

  static const _kHiddenUntil = 'social_follow_hidden_until';
  static const _kDismissedUntil = 'social_follow_dismissed_until';
  static const _kTopDay = 'social_follow_top_day';

  /// Réseaux cliqués depuis le dernier rechargement du feed (état « en cours »).
  static final Set<String> _pending = {};
  static final ValueNotifier<int> _changes = ValueNotifier(0);

  /// Tirage « 1re position » fait une seule fois par session (1 ouverture sur 5).
  static bool? _topRoll;

  /// À appeler quand le feed est rechargé : le widget cesse d'afficher
  /// l'état « en cours » (il reste masqué 1 h après un clic).
  static void onFeedReload() {
    if (_pending.isEmpty) return;
    _pending.clear();
    _changes.value++;
  }

  static String _day() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  @override
  State<SocialFollowCard> createState() => _SocialFollowCardState();
}

class _SocialFollowCardState extends State<SocialFollowCard> {
  bool _visible = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SocialFollowCard._changes.addListener(_onChange);
    _load();
  }

  @override
  void dispose() {
    SocialFollowCard._changes.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    var show = false;
    try {
      final sp = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final hidden = sp.getInt(SocialFollowCard._kHiddenUntil) ?? 0;
      final dismissed = sp.getInt(SocialFollowCard._kDismissedUntil) ?? 0;
      final pending = SocialFollowCard._pending.isNotEmpty;
      if (pending) {
        show = true; // on laisse voir « prise en compte en cours »
      } else if (now < hidden || now < dismissed) {
        show = false;
      } else if (widget.variant == SocialFollowVariant.top) {
        SocialFollowCard._topRoll ??= Random().nextInt(5) == 0;
        final today = SocialFollowCard._day();
        show = SocialFollowCard._topRoll! && sp.getString(SocialFollowCard._kTopDay) != today;
        if (show) await sp.setString(SocialFollowCard._kTopDay, today);
      } else {
        show = true;
      }
    } catch (_) {
      show = widget.variant != SocialFollowVariant.top;
    }
    if (!mounted) return;
    setState(() {
      _visible = show;
      _loaded = true;
    });
  }

  Future<void> _open(String network, String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return;
    }
    SocialFollowCard._pending.add(network);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(SocialFollowCard._kHiddenUntil,
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _dismiss() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(SocialFollowCard._kDismissedUntil,
          DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch);
    } catch (_) {}
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_visible) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    switch (widget.variant) {
      case SocialFollowVariant.slim:
        return _slim(context, colors);
      case SocialFollowVariant.end:
        return _end(context, colors);
      case SocialFollowVariant.top:
        return _card(context, colors);
    }
  }

  Widget _netButton(BuildContext context, String network, String url) {
    final isFb = network == 'facebook';
    return Expanded(
      child: Material(
        color: isFb ? const Color(0xFF1877F2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(network, url),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isFb ? Icons.facebook : Icons.music_note_rounded,
                    size: 20, color: isFb ? Colors.white : Colors.black),
                const SizedBox(width: 8),
                Text(isFb ? 'Facebook' : 'TikTok',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isFb ? Colors.white : Colors.black)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingRow(BuildContext context, AppColors colors, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: colors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(context.tr('Cela peut prendre un peu de temps'),
                style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  /// Boutons restants + lignes « prise en compte en cours ».
  Widget _actions(BuildContext context, AppColors colors) {
    final p = SocialFollowCard._pending;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (p.contains('facebook'))
        _pendingRow(context, colors, context.tr('Facebook : prise en compte en cours…')),
      if (p.contains('tiktok'))
        _pendingRow(context, colors, context.tr('TikTok : prise en compte en cours…')),
      if (!p.contains('facebook') || !p.contains('tiktok'))
        Row(children: [
          if (!p.contains('facebook'))
            _netButton(context, 'facebook', SocialFollowCard.facebookUrl),
          if (!p.contains('facebook') && !p.contains('tiktok')) const SizedBox(width: 8),
          if (!p.contains('tiktok'))
            _netButton(context, 'tiktok', SocialFollowCard.tiktokUrl),
        ]),
    ]);
  }

  Widget _logo() => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1F6B3A),
          border: Border.all(color: const Color(0xFF2A7BE4), width: 3),
        ),
        alignment: Alignment.center,
        child: const Text('A',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      );

  Widget _card(BuildContext context, AppColors colors, {bool withClose = true}) {
    final pending = SocialFollowCard._pending.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _logo(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text('Afrolook',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.verified_rounded, size: 15, color: colors.primary),
              ]),
              Text(
                  pending
                      ? context.tr('Merci pour ton soutien 💚')
                      : context.tr('12 K abonnés sur Facebook'),
                  style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ]),
          ),
          if (withClose && !pending)
            GestureDetector(
              onTap: _dismiss,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 20, color: colors.textSecondary),
              ),
            ),
        ]),
        if (!pending) ...[
          const SizedBox(height: 12),
          Text(context.tr('Rejoins-nous sur nos autres réseaux'),
              style: TextStyle(
                  color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 4),
          Text(
              context.tr(
                  'Suis, partage et commente nos publications. Plus la communauté Afrolook grandit, plus tes gains peuvent augmenter.'),
              style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        _actions(context, colors),
      ]),
    );
  }

  Widget _end(BuildContext context, AppColors colors) {
    return _card(context, colors, withClose: false);
  }

  Widget _slim(BuildContext context, AppColors colors) {
    final pending = SocialFollowCard._pending.isNotEmpty;
    if (pending) return _card(context, colors, withClose: false);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: colors.primary, width: 4),
          top: BorderSide(color: colors.border),
          right: BorderSide(color: colors.border),
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(children: [
        _miniNet(Icons.facebook, const Color(0xFF1877F2), Colors.white,
            () => _open('facebook', SocialFollowCard.facebookUrl)),
        const SizedBox(width: 6),
        _miniNet(Icons.music_note_rounded, Colors.white, Colors.black,
            () => _open('tiktok', SocialFollowCard.tiktokUrl)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Retrouve Afrolook ailleurs'),
                style: TextStyle(
                    color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            Text('Facebook · TikTok',
                style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ]),
        ),
        GestureDetector(
          onTap: _dismiss,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.close_rounded, size: 18, color: colors.textSecondary),
          ),
        ),
      ]),
    );
  }

  Widget _miniNet(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 20, color: fg),
      ),
    );
  }
}
