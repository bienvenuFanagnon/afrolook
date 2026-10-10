import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/tr.dart';
import '../../../models/model_data.dart';
import '../../../pages/cards/card_canvas.dart';
import '../../../pages/cards/card_entry.dart';
import '../../../pages/cards/card_models.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

/// Invitation du fil : « Crée ta carte Afrolook et partage-la ». Deux vraies cartes en exemple (avec le pseudo et la photo de la
/// personne), puis deux choix : une carte à partir d'un de ses posts, ou une carte neuve.
///
/// Elle revient de temps en temps seulement : au plus une fois tous les 3 jours, une seule carte à la fois dans le fil ;
/// la croix la reporte de 10 jours, et toucher un bouton la reporte de 5 jours. Jamais sur le web (le studio n'y existe pas).
class CardFeedInvite extends StatefulWidget {
  const CardFeedInvite({super.key});

  @override
  State<CardFeedInvite> createState() => _CardFeedInviteState();
}

class _CardFeedInviteState extends State<CardFeedInvite> {
  static const _kNext = 'cards_feed_invite_next_at';
  static const _day = Duration(days: 1);

  /// Décidé une fois par session : tant que le fil reste ouvert, la carte ne clignote pas.
  static bool? _showThisSession;
  static State<CardFeedInvite>? _owner;

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    if (kIsWeb) return;
    if (_showThisSession == false) return;
    if (_showThisSession == true) {
      // une seule invitation à la fois dans le fil ; elle passe à l'autre emplacement si la première n'est plus à l'écran
      if (_owner != null && _owner != this && _owner!.mounted) return;
      _owner = this;
    }
    if (_showThisSession == null) {
      var ok = true;
      try {
        final sp = await SharedPreferences.getInstance();
        final next = sp.getInt(_kNext) ?? 0;
        ok = DateTime.now().millisecondsSinceEpoch >= next;
        if (ok) await sp.setInt(_kNext, DateTime.now().add(_day * 3).millisecondsSinceEpoch);
      } catch (_) {}
      _showThisSession = ok;
      if (!ok) return;
      _owner = this;
    }
    if (_owner == this && mounted) setState(() => _visible = true);
  }

  Future<void> _snooze(int days) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_kNext, DateTime.now().add(_day * days).millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _close() async {
    await _snooze(10);
    if (mounted) setState(() => _visible = false);
  }

  Future<void> _newCard() async {
    _snooze(5);
    await CardEntry.openCompose(context);
  }

  Future<void> _fromPost() async {
    _snooze(5);
    final me = context.read<UserAuthProvider>().loginUserData;
    final c = AppColors.of(context);
    final picked = await showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => _PostPicker(userId: me.id ?? ''),
    );
    if (picked == null || !mounted) return;
    await CardEntry.openFromPost(context, picked);
  }

  /// Deux styles qui changent chaque jour : l'invitation montre des cartes différentes d'un passage à l'autre.
  static const _showy = [CardStyleId.neon, CardStyleId.kente, CardStyleId.magazine, CardStyleId.passport, CardStyleId.manga, CardStyleId.gamer, CardStyleId.wax, CardStyleId.glass, CardStyleId.flag];

  Widget _example(CardStyleId style, double w, double angle, {required bool withImage, required UserData me, required String text}) {
    final avatar = (me.imageUrl ?? '').isNotEmpty ? CachedNetworkImageProvider(me.imageUrl!) : null;
    final source = CardSource(
      pseudo: me.pseudo ?? 'afrolook',
      avatar: avatar,
      verified: me.isVerify == true,
      text: text,
      images: withImage ? const [AssetImage('assets/images/intro3.jpg')] : const [],
      likes: 1200,
      comments: 86,
      country: me.countryData?['countryCode'],
      profileId: me.id,
      date: DateTime.now(),
    );
    final spec = CardSpec(style: style, country: me.countryData?['countryCode']);
    final size = spec.format.size;
    final h = w * size.height / size.width;
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: IgnorePointer(child: FittedBox(fit: BoxFit.cover, child: CardCanvas(source: source, spec: spec, text: text))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || kIsWeb) return const SizedBox.shrink();
    final me = context.read<UserAuthProvider>().loginUserData;
    final doy = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final s1 = _showy[doy % _showy.length];
    final s2 = _showy[(doy + 4) % _showy.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFF0E3B22), Color(0xFF0A100C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: const Color(0xFFF2B705).withOpacity(0.7), width: 1.2),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF2B705), size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(context.tr('STUDIO CARTES'), style: const TextStyle(color: Color(0xFFF2B705), fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 1))),
            InkWell(onTap: _close, borderRadius: BorderRadius.circular(20), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close_rounded, size: 18, color: Colors.white60))),
          ]),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('Crée ta carte Afrolook'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.15)),
                  const SizedBox(height: 6),
                  Text(context.tr('Fais d\'un de tes posts, ou d\'une idée neuve, une belle carte à partager sur WhatsApp, Instagram ou TikTok.'), style: const TextStyle(color: Color(0xFFC9D1CC), fontSize: 12.5, height: 1.35)),
                ]),
              ),
            ),
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(left: 0, top: 8, child: _example(s1, 84, -0.09, withImage: true, me: me, text: context.tr('Ma plus belle prise de la saison, merci à tous !'))),
                Positioned(right: 0, top: 22, child: _example(s2, 84, 0.08, withImage: false, me: me, text: context.tr('Aujourd\'hui, je lance quelque chose de grand. #afrolook'))),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _fromPost,
                icon: const Icon(Icons.article_outlined, size: 18),
                label: Text(context.tr('Depuis un de mes posts'), maxLines: 1, overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF2B705), foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _newCard,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr('Nouvelle carte'), maxLines: 1, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 11)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Liste des derniers posts de la personne : elle touche celui qu'elle veut transformer en carte.
class _PostPicker extends StatelessWidget {
  const _PostPicker({required this.userId});
  final String userId;

  Future<List<Post>> _load() async {
    final snap = await FirebaseFirestore.instance.collection('Posts').where('user_id', isEqualTo: userId).orderBy('created_at', descending: true).limit(20).get();
    final out = <Post>[];
    for (final d in snap.docs) {
      try {
        final p = Post.fromJson(d.data());
        p.id ??= d.id;
        if (p.isAdvertisement == true) continue;
        if ((p.description ?? '').trim().isEmpty && (p.images ?? const []).isEmpty) continue;
        out.add(p);
      } catch (_) {}
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Align(alignment: Alignment.centerLeft, child: Text(context.tr('Choisis un post'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
          ),
          Flexible(
            child: FutureBuilder<List<Post>>(
              future: _load(),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator());
                final posts = snap.data ?? const <Post>[];
                if (posts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(context.tr('Tu n\'as pas encore de post à transformer.'), style: TextStyle(color: c.textSecondary), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: () { Navigator.pop(ctx); CardEntry.openCompose(context); }, child: Text(context.tr('Nouvelle carte'))),
                    ]),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = posts[i];
                    final img = (p.images ?? const <String>[]).isNotEmpty ? p.images!.first : '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 52, height: 52, child: img.isNotEmpty ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => ColoredBox(color: c.surfaceVariant)) : ColoredBox(color: c.surfaceVariant, child: Icon(Icons.text_fields_rounded, color: c.textSecondary))),
                      ),
                      title: Text((p.description ?? '').trim().isEmpty ? context.tr('Post avec image') : p.description!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 14)),
                      trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
