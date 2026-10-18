import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/authProvider.dart';
import 'ad_config.dart';
import 'ad_gate.dart';
import 'admob_native_pool.dart';
import 'admob_service.dart';
import 'admob_widgets.dart';
import 'music_ads.dart';

/// Emplacement publicitaire : pub Afrolook ou pub AdMob, jamais les deux.
///
/// - AdMob possible : AdMob, toujours en priorité (fil, détails, commentaires, listes, chroniques…).
/// - Une seule des deux disponible : celle-là.
/// - AdMob ne charge pas : repli sur la pub Afrolook ; sinon rien (aucun trou dans la page).
/// - Aucun utilisateur Gold (admin excepté) ne voit de pub (voir [AdGate.userSeesAds]).
enum AdSlotKind {
  /// Fil d'actualité : pub native moyenne.
  feed,
  /// Page de détail : bannière adaptative.
  detail,
  /// Page de détail : grand format 300×250.
  detailMrec,
  /// Commentaires : petite pub native.
  comments,
  /// Listes (profils, services, défis…) : petite pub native.
  list,
  /// Liste des conversations : petite pub native.
  chatList,
  /// Fil d'un groupe : petite pub native entre deux messages.
  groupFeed,
  /// Groupe gratuit : bannière adaptative fixe au-dessus de la saisie.
  groupBanner,
  /// Page Musique : bannière sous la liste (emplacement AdMob dédié).
  musicBanner,
  /// Page Musique : pub native entre les titres (emplacement AdMob dédié).
  musicList,
}

class AdSlot extends StatefulWidget {
  const AdSlot({Key? key, required this.kind, required this.own, this.admobFirst = false}) : super(key: key);
  final AdSlotKind kind;

  /// AdMob en priorité ; la pub Afrolook ne s'affiche que si AdMob n'est pas disponible ou ne charge pas.
  final bool admobFirst;

  /// Construit la pub Afrolook de cet emplacement (ex. `() => const AfrolookInlineAd()`).
  final Widget Function() own;

  @override
  State<AdSlot> createState() => _AdSlotState();
}

enum _Mode { own, admob, none }

class _AdSlotState extends State<AdSlot> {
  _Mode? _mode;
  bool _admobFailed = false;

  bool _kindEnabled() {
    final c = AdConfig.current;
    switch (widget.kind) {
      case AdSlotKind.feed:
        return true;
      case AdSlotKind.detail:
        return c.detailBanner;
      case AdSlotKind.detailMrec:
        return c.detailMrec;
      case AdSlotKind.comments:
        return c.commentsNative;
      case AdSlotKind.list:
        return c.listsNative;
      case AdSlotKind.chatList:
        return c.chatListNative;
      case AdSlotKind.groupFeed:
        return c.groupsNative;
      case AdSlotKind.groupBanner:
        return c.groupsBanner;
      case AdSlotKind.musicBanner:
        return c.musicBanner;
      case AdSlotKind.musicList:
        return c.musicNative;
    }
  }

  String get _type => (widget.kind == AdSlotKind.detail ||
          widget.kind == AdSlotKind.detailMrec ||
          widget.kind == AdSlotKind.groupBanner ||
          widget.kind == AdSlotKind.musicBanner)
      ? 'banner'
      : 'native';

  _Mode _decide(UserAuthProvider auth) {
    final user = auth.loginUserData;
    if (!AdGate.userSeesAds(user)) return _Mode.none;
    final ownAvailable = auth.advertisements.isNotEmpty;
    final admobOk = !_admobFailed && _kindEnabled() && AdGate.canShowType(user, _type);
    // AdMob d'abord, partout : la pub Afrolook ne passe que si AdMob n'est pas disponible
    // (désactivé, pas encore chargé, comptes neufs, pas de bloc d'annonce) ou ne charge pas.
    if (admobOk) return _Mode.admob;
    return ownAvailable ? _Mode.own : _Mode.none;
  }

  @override
  void initState() {
    super.initState();
    // Une pub native de plus se prépare dès qu'un emplacement apparaît : le suivant s'affichera sans attente
    if (_type == 'native') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AdmobNativePool.warmUpWhenReady(context, context.read<UserAuthProvider>().loginUserData);
      });
    }
  }

  void _onAdmobFailed() {
    if (!mounted) return;
    setState(() {
      _admobFailed = true;
      _mode = null; // redécide : repli sur la pub Afrolook
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<UserAuthProvider>();
    AdmobService.ensureInit();
    return ValueListenableBuilder<bool>(
      valueListenable: AdmobService.ready,
      builder: (context, _, __) {
        // Redécide tant que rien n'est affiché (pubs Afrolook ou SDK arrivés après coup)
        if (_mode == null || _mode == _Mode.none) _mode = _decide(auth);
        switch (_mode!) {
          case _Mode.own:
            return widget.own();
          case _Mode.admob:
            switch (widget.kind) {
              case AdSlotKind.detail:
              case AdSlotKind.groupBanner:
                return AdmobBannerWidget(onFailed: _onAdmobFailed);
              case AdSlotKind.detailMrec:
                return AdmobBannerWidget(mrec: true, onFailed: _onAdmobFailed);
              case AdSlotKind.musicBanner:
                return AdmobBannerWidget(unitKey: 'musicBanner', onPaid: MusicAds.paid('banner'), onFailed: _onAdmobFailed);
              case AdSlotKind.musicList:
                return AdmobNativeWidget(small: true, unitKey: 'musicNative', onPaid: MusicAds.paid('native'), onFailed: _onAdmobFailed);
              case AdSlotKind.feed:
                return AdmobNativeWidget(onFailed: _onAdmobFailed);
              case AdSlotKind.comments:
              case AdSlotKind.list:
              case AdSlotKind.chatList:
              case AdSlotKind.groupFeed:
                return AdmobNativeWidget(small: true, onFailed: _onAdmobFailed);
            }
          case _Mode.none:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
