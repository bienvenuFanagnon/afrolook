import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

import '../providers/authProvider.dart';
import 'ad_gate.dart';
import 'appodeal_service.dart';

/// Bannière Appodeal (320×50) ou grand format (300×250).
///
/// - La hauteur est réservée tout de suite (pas de saut d'affichage) ; si aucune pub n'arrive en [_patience], l'emplacement disparaît
///   (`SizedBox.shrink`) et [onFailed] permet le repli sur la pub Afrolook : jamais de grand vide.
/// - Aucune pub pour les comptes qui n'en voient pas (Gold, pubs coupées, comptes neufs, hors pourcentage) : mêmes règles que les autres
///   publicités ([AdGate.canShowAdmob]).
/// - Une erreur de pub ne bloque jamais l'écran ; le rafraîchissement est géré par le SDK (pas de rechargement en boucle ici).
/// - La vue native est détruite avec le widget : rien ne reste affiché ni en mémoire quand l'écran est quitté.
class AppodealBannerWidget extends StatefulWidget {
  const AppodealBannerWidget({Key? key, this.mrec = false, this.onFailed, this.placement = 'default', this.quickFallback = false}) : super(key: key);
  final bool mrec;
  final VoidCallback? onFailed;
  final String placement;

  /// Abandonne dès le premier échec signalé par le SDK (au lieu d'attendre la fin du délai) : l'appelant a un repli prêt (AdMob en direct).
  final bool quickFallback;

  @override
  State<AppodealBannerWidget> createState() => _AppodealBannerWidgetState();
}

class _AppodealBannerWidgetState extends State<AppodealBannerWidget> {
  /// Délai avant de considérer qu'aucune pub ne viendra pour cet emplacement.
  static const Duration _patience = Duration(seconds: 12);

  bool _loaded = false;
  bool _failed = false;
  Timer? _timer;
  late final ValueNotifier<int> _okEvents = widget.mrec ? AppodealService.mrecLoaded : AppodealService.bannerLoaded;
  late final ValueNotifier<int> _koEvents = widget.mrec ? AppodealService.mrecFailed : AppodealService.bannerFailed;
  late final int _okAtStart = _okEvents.value;
  late final int _koAtStart = _koEvents.value;

  @override
  void initState() {
    super.initState();
    // références de départ figées maintenant (les événements d'avant ne comptent pas)
    _okAtStart;
    _koAtStart;
    _okEvents.addListener(_onEvent);
    _koEvents.addListener(_onEvent);
    _timer = Timer(_patience, () => _giveUp());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _okEvents.removeListener(_onEvent);
    _koEvents.removeListener(_onEvent);
    super.dispose();
  }

  void _onEvent() {
    if (!mounted || _failed) return;
    if (_okEvents.value > _okAtStart) {
      _timer?.cancel();
      AppodealService.noteBannerResult(ok: true);
      if (!_loaded) setState(() => _loaded = true);
      return;
    }
    if (widget.quickFallback && !_loaded && _koEvents.value > _koAtStart) _giveUp();
    // Échec signalé sans qu'une pub n'ait été chargée : on laisse le SDK réessayer jusqu'à la fin du délai (il continue seul)
  }

  void _giveUp() {
    if (!mounted || _loaded || _failed) return;
    AppodealService.noteBannerResult(ok: false);
    setState(() => _failed = true);
    widget.onFailed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserAuthProvider>().loginUserData;
    if (_failed || !AdGate.canShowAdmob(user)) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: AppodealService.ready,
      builder: (context, ready, _) {
        if (!ready) return const SizedBox.shrink(); // SDK pas encore prêt : l'emplacement attend sans rien réserver
        final size = widget.mrec ? AppodealBannerSize.MEDIUM_RECTANGLE : AppodealBannerSize.BANNER;
        return Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 6),
          height: size.height.toDouble(),
          child: AppodealBanner(adSize: size, placement: widget.placement),
        );
      },
    );
  }
}
