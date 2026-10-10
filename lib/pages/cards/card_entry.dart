import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import 'card_flow.dart';
import 'card_models.dart';
import 'card_service.dart';
import 'card_studio_page.dart';

/// Points d'entrée du Studio Cartes : menu d'un post, appui long, page de création de post, tutoriel.
class CardEntry {
  CardEntry._();

  /// « NOUVEAU » reste affiché sur l'entrée du menu tant que le studio n'a pas été ouvert une fois.
  static final ValueNotifier<bool> isNew = ValueNotifier<bool>(false);
  static bool _loaded = false;

  static Future<void> loadNewFlag() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      isNew.value = sp.getBool('cards_opened') != true;
    } catch (_) {}
  }

  static Future<void> _markOpened() async {
    isNew.value = false;
    try {
      (await SharedPreferences.getInstance()).setBool('cards_opened', true);
    } catch (_) {}
  }

  /// Ce post peut-il devenir une carte ? Pas les publicités, ni les posts d'un canal privé (sauf pour leur auteur
  /// et les administrateurs) : une carte sort de l'application, elle ne doit pas révéler un contenu réservé.
  static bool canMake(Post post, UserData me) {
    if (kIsWeb) return false; // le studio n'existe que dans l'application
    if (post.isAdvertisement == true) return false;
    if (post.canal?.isPrivate == true && post.user_id != me.id && me.role != UserRole.ADM.name) return false;
    return true;
  }

  /// Ouvre le studio à partir d'un post.
  static Future<void> openFromPost(BuildContext context, Post post) async {
    final auth = context.read<UserAuthProvider>();
    final me = auth.loginUserData;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (!canMake(post, me)) {
      messenger.showSnackBar(SnackBar(content: Text(tr('Ce post ne peut pas devenir une carte.'))));
      return;
    }
    UserData? author = post.user;
    if (author == null && (post.user_id ?? '').isNotEmpty) {
      try {
        final d = await FirebaseFirestore.instance.collection('Users').doc(post.user_id).get();
        if (d.exists) author = UserData.fromJson({...d.data()!, 'id': d.id});
      } catch (_) {}
    }
    final isVideo = post.dataType == PostDataType.VIDEO.name;
    final List<String> images = isVideo
        ? [if ((post.thumbnail ?? '').isNotEmpty) post.thumbnail!]
        : (post.images ?? const <String>[]).where((u) => u.isNotEmpty).toList();
    final avatar = (author?.imageUrl ?? '').isNotEmpty ? CachedNetworkImageProvider(author!.imageUrl!) : null;
    final mine = post.user_id == me.id;
    final source = CardSource(
      pseudo: author?.pseudo ?? 'afrolook',
      avatar: avatar,
      verified: author?.isVerify == true,
      text: post.description ?? '',
      images: [for (final u in images) CachedNetworkImageProvider(u)],
      isVideo: isVideo && images.isNotEmpty,
      postId: post.id,
      date: _date(post.createdAt),
      likes: (post.loves ?? 0) > (post.likes ?? 0) ? post.loves! : (post.likes ?? 0),
      comments: post.comments ?? 0,
      followers: author?.followersCount ?? 0,
      profileId: author?.id ?? post.user_id,
      country: author?.countryData?['countryCode'],
      credit: mine ? null : 'carte de @${me.pseudo ?? 'afrolook'}',
    );
    _markOpened();
    await nav.push(MaterialPageRoute(builder: (_) => CardStudioPage(source: source)));
  }

  /// Petite feuille proposée à l'appui long sur un post sans menu « ⋯ » (cartes vidéo du fil).
  static Future<void> showQuickSheet(BuildContext context, Post post) async {
    final me = context.read<UserAuthProvider>().loginUserData;
    if (!canMake(post, me)) return;
    final c = AppColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CardMenuTile(onTap: () {
              Navigator.pop(ctx);
              openFromPost(context, post);
            }),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    Icon(Icons.cancel, color: c.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Text(ctx.tr('Annuler'), style: TextStyle(color: c.textSecondary, fontSize: 16)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static DateTime? _date(int? t) {
    if (t == null || t <= 0) return null;
    return t > 100000000000000 ? DateTime.fromMicrosecondsSinceEpoch(t) : DateTime.fromMillisecondsSinceEpoch(t);
  }

  /// Mode carte de la page de création de post : crée une carte puis la publie avec les règles des posts.
  /// [style] et [country] pré-règlent le studio (invitations des fêtes : drapeau du pays, style du jour).
  static Future<void> openCompose(BuildContext context, {Canal? canal, String? defiPostId, String text = '', List<Uint8List> images = const [], CardStyleId? style, String? country, bool askLink = false, CardTemplateId? template}) =>
      composeOn(Navigator.of(context), canal: canal, defiPostId: defiPostId, text: text, images: images, style: style, country: country, askLink: askLink, template: template);

  static Future<void> composeOn(NavigatorState nav, {Canal? canal, String? defiPostId, String text = '', List<Uint8List> images = const [], CardStyleId? style, String? country, bool askLink = false, CardTemplateId? template}) async {
    final ctx = nav.context;
    final me = ctx.read<UserAuthProvider>().loginUserData;
    final avatar = (me.imageUrl ?? '').isNotEmpty ? CachedNetworkImageProvider(me.imageUrl!) : null;
    final source = CardSource.draft(pseudo: me.pseudo ?? 'afrolook', avatar: avatar, verified: me.isVerify == true, text: text, imageBytes: images, followers: me.followersCount, profileId: me.id, country: me.countryData?['countryCode']);
    _markOpened();
    final result = await nav.push<Object?>(MaterialPageRoute(builder: (_) => CardStudioPage(source: source, compose: true, canal: canal, defiPostId: defiPostId, initialStyle: style, initialCountry: country, askLink: askLink, initialTemplate: template)));
    if (result is! CardResult || !nav.mounted) return;
    final quote = await CardService.quote();
    if (!nav.mounted) return;
    await CardFlow.publishAsPost(nav.context, result, quote, canal: canal, defiPostId: defiPostId);
  }
}

/// Ligne « Créer une carte Afrolook » pour les menus de post (même gabarit que les autres lignes), avec son badge NOUVEAU.
class CardMenuTile extends StatelessWidget {
  const CardMenuTile({super.key, required this.onTap, this.color});
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    CardEntry.loadNewFlag();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(children: [
            Icon(Icons.auto_awesome_rounded, color: c.primary, size: 20),
            const SizedBox(width: 12),
            Text(context.tr('Créer une carte Afrolook'), style: TextStyle(color: color ?? c.textPrimary, fontSize: 16)),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: CardEntry.isNew,
              builder: (_, isNew, __) => isNew
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(5)),
                      child: const Text('NOUVEAU', style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
                    )
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
      ),
    );
  }
}
