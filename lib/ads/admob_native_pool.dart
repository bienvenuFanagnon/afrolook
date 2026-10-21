import 'dart:async';
import 'ad_revenue_tracker.dart';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/model_data.dart';
import '../theme/app_colors.dart';
import 'ad_config.dart';
import 'ad_gate.dart';
import 'admob_service.dart';

/// Réservoir de pubs natives AdMob chargées d'avance.
///
/// Sans lui, une pub ne commence à se charger que lorsque son emplacement entre à l'écran : elle arrive 1 à 3 secondes plus tard,
/// souvent après que la personne a déjà fait défiler le fil. Ici quelques pubs sont déjà prêtes ; l'emplacement en prend une
/// (affichage immédiat), et le réservoir en recharge une autre aussitôt pour le suivant.
///
/// Règles AdMob respectées : une pub n'est montrée que dans un seul emplacement, jamais gardée plus de 50 minutes (elles expirent
/// au bout d'une heure), et le réservoir reste petit pour ne pas demander des pubs qui ne seront jamais vues.
class AdmobNativePool {
  AdmobNativePool._();

  /// Pubs gardées d'avance : format moyen (fil) et petit format (commentaires, listes).
  static const int mediumTarget = 2;
  static const int smallTarget = 1;
  static const Duration maxAge = Duration(minutes: 50);
  static const Duration _retryAfterFail = Duration(seconds: 45);

  static final Map<String, List<_Ready>> _ready = {};
  static final Map<String, int> _loading = {};
  static final Map<String, DateTime> _failedAt = {};
  static final Map<String, _Spec> _specs = {};

  static String _key(bool small, Brightness b) => '${small ? 's' : 'm'}_${b.name}';

  /// Prépare les pubs du fil et des commentaires pour ce thème (clair ou sombre). Sans effet si AdMob n'est pas disponible
  /// pour cette personne (Gold, pubs coupées, compte neuf, SDK pas prêt…) : on ne demande rien pour rien.
  static void warmUp(BuildContext context, UserData? user) {
    if (!AdConfig.isMobile || !AdGate.canShowType(user, 'native')) return;
    final colors = AppColors.of(context);
    final brightness = Theme.of(context).brightness;
    for (final small in const [false, true]) {
      final key = _key(small, brightness);
      _specs[key] = _Spec(colors: colors, small: small);
      _refill(key);
    }
  }

  /// Le SDK n'est pas toujours prêt au démarrage : on lance le réchauffement dès qu'il l'est.
  static void warmUpWhenReady(BuildContext context, UserData? user) {
    if (AdmobService.ready.value) {
      warmUp(context, user);
      return;
    }
    AdmobService.ensureInit();
    void once() {
      if (!AdmobService.ready.value) return;
      AdmobService.ready.removeListener(once);
      if (context.mounted) warmUp(context, user);
    }

    AdmobService.ready.addListener(once);
  }

  /// Une pub prête pour cet emplacement, ou null (l'emplacement se charge alors lui-même). La pub est retirée du réservoir :
  /// l'emplacement en devient propriétaire et la libère à sa fermeture.
  static NativeAd? take({required bool small, required Brightness brightness}) {
    final key = _key(small, brightness);
    final list = _ready[key];
    NativeAd? out;
    if (list != null) {
      final now = DateTime.now();
      while (list.isNotEmpty && out == null) {
        final r = list.removeAt(0);
        if (now.difference(r.at) > maxAge) {
          r.ad.dispose();
        } else {
          out = r.ad;
        }
      }
    }
    _refill(key);
    return out;
  }

  static int readyCount({required bool small, required Brightness brightness}) =>
      _ready[_key(small, brightness)]?.length ?? 0;

  static void _refill(String key) {
    final spec = _specs[key];
    if (spec == null) return;
    final unit = AdConfig.current.unit('native');
    if (unit.isEmpty) return;
    final failed = _failedAt[key];
    if (failed != null && DateTime.now().difference(failed) < _retryAfterFail) return;
    final list = _ready.putIfAbsent(key, () => []);
    list.removeWhere((r) {
      final old = DateTime.now().difference(r.at) > maxAge;
      if (old) r.ad.dispose();
      return old;
    });
    final target = spec.small ? smallTarget : mediumTarget;
    var missing = target - list.length - (_loading[key] ?? 0);
    while (missing-- > 0) {
      _loading[key] = (_loading[key] ?? 0) + 1;
      late final NativeAd ad;
      ad = NativeAd(
        adUnitId: unit,
        request: AdmobService.request(),
        listener: NativeAdListener(
          onPaidEvent: (a, micros, precision, currency) => AdRevenueTracker.record('admob_native_pool', micros, currency),
          onAdLoaded: (_) {
            _loading[key] = (_loading[key] ?? 1) - 1;
            _failedAt.remove(key);
            list.add(_Ready(ad, DateTime.now()));
          },
          onAdFailedToLoad: (a, e) {
            _loading[key] = (_loading[key] ?? 1) - 1;
            _failedAt[key] = DateTime.now();
            AdmobService.lastErrors['natif'] = 'code ${e.code} : ${e.message}';
            a.dispose();
          },
        ),
        nativeTemplateStyle: nativeStyle(spec.colors, small: spec.small),
      );
      ad.load();
    }
  }

  /// Habillage commun (réservoir et chargement direct) aux couleurs de l'application.
  static NativeTemplateStyle nativeStyle(AppColors colors, {required bool small}) {
    NativeTemplateTextStyle ts(Color c, {bool bold = false, double size = 13}) => NativeTemplateTextStyle(
          textColor: c,
          style: bold ? NativeTemplateFontStyle.bold : NativeTemplateFontStyle.normal,
          size: size,
        );
    return NativeTemplateStyle(
      templateType: small ? TemplateType.small : TemplateType.medium,
      mainBackgroundColor: colors.surface,
      cornerRadius: 12,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: colors.onPrimary,
        backgroundColor: colors.primary,
        style: NativeTemplateFontStyle.bold,
        size: 13,
      ),
      primaryTextStyle: ts(colors.textPrimary, bold: true, size: 14),
      secondaryTextStyle: ts(colors.textSecondary, size: 12),
      tertiaryTextStyle: ts(colors.textSecondary, size: 11),
    );
  }

  /// Libère tout (déconnexion, pubs coupées).
  static void clear() {
    for (final l in _ready.values) {
      for (final r in l) {
        r.ad.dispose();
      }
      l.clear();
    }
    _failedAt.clear();
  }
}

class _Ready {
  _Ready(this.ad, this.at);
  final NativeAd ad;
  final DateTime at;
}

class _Spec {
  _Spec({required this.colors, required this.small});
  final AppColors colors;
  final bool small;
}
