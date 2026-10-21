import 'dart:async';

import 'package:flutter/material.dart';

import 'admob_widgets.dart';
import 'appodeal_service.dart';
import 'appodeal_widgets.dart';

/// Bannière (ou grand format 300×250) : Appodeal quand `AppConfig/ads.bannerProvider` vaut `appodeal` (par défaut, AdMob médié), sinon AdMob
/// en direct. À utiliser à la place de [AdmobBannerWidget] / [AppodealBannerWidget] dans les pages.
///
/// Repli : si Appodeal ne sert rien (SDK pas prêt, premier échec de chargement), l'emplacement passe à AdMob en direct. Jamais les deux en
/// même temps sur un emplacement. Après 3 échecs de suite, les emplacements vont directement à AdMob pendant 10 minutes, puis Appodeal est
/// retenté ([AppodealService.skipBanners]). [onFailed] n'est appelé que si AdMob échoue aussi (l'écran peut alors montrer une pub Afrolook).
class AdBanner extends StatefulWidget {
  const AdBanner({Key? key, this.mrec = false, this.onFailed, this.unitKey = 'banner', this.onPaid}) : super(key: key);
  final bool mrec;
  final VoidCallback? onFailed;

  /// Emplacement AdMob (repli AdMob seulement) et suivi du revenu estimé.
  final String unitKey;
  final void Function(double valueMicros, String currency)? onPaid;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  /// Appodeal toujours pas prêt après ce délai : l'emplacement passe à AdMob en direct.
  static const Duration _waitForSdk = Duration(seconds: 3);
  Timer? _timer;

  /// Appodeal n'a rien servi : cet emplacement affiche AdMob en direct.
  bool _fallback = false;

  @override
  void initState() {
    super.initState();
    if (!AppodealService.bannersViaAppodeal) return;
    if (AppodealService.skipBanners) {
      _fallback = true; // Appodeal ne remplit pas depuis un moment : AdMob d'emblée, sans attente
    } else if (!AppodealService.ready.value) {
      _timer = Timer(_waitForSdk, () {
        if (mounted && !AppodealService.ready.value) _toFallback();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toFallback() {
    if (mounted && !_fallback) setState(() => _fallback = true);
  }

  @override
  Widget build(BuildContext context) {
    if (AppodealService.bannersViaAppodeal && !_fallback) {
      return ValueListenableBuilder<bool>(
        valueListenable: AppodealService.ready,
        // Appodeal pas encore prêt : l'emplacement n'occupe rien et n'affiche pas encore AdMob (jamais deux fournisseurs en même temps)
        builder: (context, ready, _) => ready
            ? AppodealBannerWidget(mrec: widget.mrec, quickFallback: true, onFailed: _toFallback)
            : const SizedBox.shrink(),
      );
    }
    return AdmobBannerWidget(mrec: widget.mrec, onFailed: widget.onFailed, unitKey: widget.unitKey, onPaid: widget.onPaid);
  }
}
