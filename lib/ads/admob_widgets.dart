import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../providers/authProvider.dart';
import '../theme/app_colors.dart';
import 'ad_config.dart';
import 'ad_gate.dart';
import 'ad_revenue_tracker.dart';
import 'admob_native_pool.dart';
import 'admob_service.dart';

/// Bannière adaptative (fixe, en bas des pages de détail) ou grand format 300×250.
/// N'occupe aucune place tant que la pub n'est pas chargée ; [onFailed] permet un repli.
class AdmobBannerWidget extends StatefulWidget {
  const AdmobBannerWidget({Key? key, this.mrec = false, this.onFailed, this.unitKey = 'banner', this.onPaid}) : super(key: key);
  final bool mrec;

  /// Emplacement AdMob utilisé (`banner`, ou `musicBanner` pour la page Musique) et suivi du revenu estimé.
  final String unitKey;
  final void Function(double valueMicros, String currency)? onPaid;
  final VoidCallback? onFailed;

  @override
  State<AdmobBannerWidget> createState() => _AdmobBannerWidgetState();
}

class _AdmobBannerWidgetState extends State<AdmobBannerWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _started = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _load(double width) async {
    if (_started) return;
    _started = true;
    final unit = AdConfig.current.unit(widget.unitKey);
    if (unit.isEmpty) {
      widget.onFailed?.call();
      return;
    }
    final AdSize? size = widget.mrec
        ? AdSize.mediumRectangle
        : await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width.truncate());
    if (size == null || !mounted) {
      widget.onFailed?.call();
      return;
    }
    final ad = BannerAd(
      adUnitId: unit,
      size: size,
      request: AdmobService.request(),
      listener: BannerAdListener(
        onPaidEvent: (a, micros, precision, currency) {
          AdRevenueTracker.record(widget.mrec ? 'admob_mrec' : 'admob_banner_${widget.unitKey}', micros, currency);
          widget.onPaid?.call(micros, currency);
        },
        onAdLoaded: (a) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, e) {
          AdmobService.lastErrors['bannière'] = 'code ${e.code} : ${e.message}';
          a.dispose();
          _ad = null;
          widget.onFailed?.call();
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserAuthProvider>().loginUserData;
    if (!AdGate.canShowType(user, 'banner')) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(c.maxWidth);
      });
      final ad = _ad;
      if (!_loaded || ad == null) return const SizedBox.shrink();
      return Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 6),
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    });
  }
}

/// Pub native habillée aux couleurs de l'app, dans un cadre « Sponsorisé » aligné sur nos cartes.
/// [small] : petit format (commentaires, listes) ; sinon format moyen (feed).
class AdmobNativeWidget extends StatefulWidget {
  const AdmobNativeWidget({Key? key, this.small = false, this.onFailed, this.unitKey = 'native', this.onPaid}) : super(key: key);
  final bool small;
  final String unitKey;
  final void Function(double valueMicros, String currency)? onPaid;
  final VoidCallback? onFailed;

  @override
  State<AdmobNativeWidget> createState() => _AdmobNativeWidgetState();
}

class _AdmobNativeWidgetState extends State<AdmobNativeWidget> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _started = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  /// Une pub déjà chargée d'avance (réservoir) : affichée dès la première image, sans attendre le réseau.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || widget.onPaid != null || widget.unitKey != 'native') return;
    final pooled = AdmobNativePool.take(small: widget.small, brightness: Theme.of(context).brightness);
    if (pooled != null) {
      _started = true;
      _ad = pooled;
      _loaded = true;
    }
  }

  void _load(AppColors colors) {
    if (_started) return;
    _started = true;
    final unit = AdConfig.current.unit(widget.unitKey);
    if (unit.isEmpty) {
      widget.onFailed?.call();
      return;
    }
    final ad = NativeAd(
      adUnitId: unit,
      request: AdmobService.request(),
      listener: NativeAdListener(
        onPaidEvent: (a, micros, precision, currency) {
          AdRevenueTracker.record('admob_native_${widget.unitKey}', micros, currency);
          widget.onPaid?.call(micros, currency);
        },
        onAdLoaded: (a) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, e) {
          AdmobService.lastErrors['natif'] = 'code ${e.code} : ${e.message}';
          a.dispose();
          _ad = null;
          widget.onFailed?.call();
        },
      ),
      nativeTemplateStyle: AdmobNativePool.nativeStyle(colors, small: widget.small),
    );
    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserAuthProvider>().loginUserData;
    if (!AdGate.canShowType(user, 'native')) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(colors);
    });
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: widget.small ? 8 : 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(4)),
              child: const Text('SPONSORISÉ',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xFF1F1F1F))),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.small ? 90 : 320,
              maxHeight: widget.small ? 120 : 360,
            ),
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
  }
}
