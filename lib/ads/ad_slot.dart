import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/authProvider.dart';
import 'ad_config.dart';
import 'ad_gate.dart';
import 'admob_service.dart';
import 'admob_widgets.dart';

/// Emplacement publicitaire : pub Afrolook ou pub AdMob, jamais les deux.
///
/// - Pub Afrolook disponible ET AdMob possible : alternance (1 emplacement sur [AdConfig.admobEvery] à AdMob).
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
}

class AdSlot extends StatefulWidget {
  const AdSlot({Key? key, required this.kind, required this.own}) : super(key: key);
  final AdSlotKind kind;

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
    }
  }

  String get _type => (widget.kind == AdSlotKind.detail || widget.kind == AdSlotKind.detailMrec) ? 'banner' : 'native';

  _Mode _decide(UserAuthProvider auth) {
    final user = auth.loginUserData;
    if (!AdGate.userSeesAds(user)) return _Mode.none;
    final ownAvailable = auth.advertisements.isNotEmpty;
    final admobOk = !_admobFailed && _kindEnabled() && AdGate.canShowType(user, _type);
    if (!admobOk) return ownAvailable ? _Mode.own : _Mode.none;
    if (!ownAvailable) return _Mode.admob;
    return AdGate.nextSlotIsAdmob() ? _Mode.admob : _Mode.own;
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
                return AdmobBannerWidget(onFailed: _onAdmobFailed);
              case AdSlotKind.detailMrec:
                return AdmobBannerWidget(mrec: true, onFailed: _onAdmobFailed);
              case AdSlotKind.feed:
                return AdmobNativeWidget(onFailed: _onAdmobFailed);
              case AdSlotKind.comments:
              case AdSlotKind.list:
                return AdmobNativeWidget(small: true, onFailed: _onAdmobFailed);
            }
          case _Mode.none:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
