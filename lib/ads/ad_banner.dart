import 'dart:async';

import 'package:flutter/material.dart';

import 'admob_widgets.dart';
import 'appodeal_service.dart';
import 'appodeal_widgets.dart';

/// Bannière (ou grand format 300×250) : Appodeal quand `AppConfig/ads.bannerProvider` vaut `appodeal` (par défaut, AdMob médié), sinon AdMob
/// en direct. Un seul fournisseur est actif à la fois. À utiliser à la place de [AdmobBannerWidget] / [AppodealBannerWidget] dans les pages.
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
  /// Appodeal toujours pas prêt après ce délai : l'emplacement signale son échec (l'écran peut passer à autre chose ou montrer une pub Afrolook).
  static const Duration _waitForSdk = Duration(seconds: 3);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (AppodealService.bannersViaAppodeal && !AppodealService.ready.value) {
      _timer = Timer(_waitForSdk, () {
        if (mounted && !AppodealService.ready.value) widget.onFailed?.call();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppodealService.bannersViaAppodeal) {
      return ValueListenableBuilder<bool>(
        valueListenable: AppodealService.ready,
        // Appodeal pas encore prêt : l'emplacement n'occupe rien (et ne se tourne pas vers AdMob : jamais deux fournisseurs en même temps)
        builder: (context, ready, _) => ready ? AppodealBannerWidget(mrec: widget.mrec, onFailed: widget.onFailed) : const SizedBox.shrink(),
      );
    }
    return AdmobBannerWidget(mrec: widget.mrec, onFailed: widget.onFailed, unitKey: widget.unitKey, onPaid: widget.onPaid);
  }
}
