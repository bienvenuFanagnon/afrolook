import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ads/ad_config.dart';
import '../../ads/ad_gate.dart';
import '../../ads/admob_service.dart';
import '../../providers/authProvider.dart';

/// Publicités des actualités. Avant d'ouvrir une source (un site extérieur), une pub plein écran est montrée : la personne quitte Afrolook, c'est
/// le bon moment. Souvent mais pas à chaque fois : 2 minutes au moins entre deux pubs plein écran de ce type, 8 par jour au plus. Les règles
/// générales de l'application s'appliquent (aucune pub pour un abonné Gold, pourcentage de déploiement, réglages à distance), et AdMob passe la main
/// à Appodeal quand il n'a rien de prêt. Ne bloque jamais l'ouverture : aucune pub disponible, la source s'ouvre tout de suite.
class NewsAds {
  NewsAds._();

  static const _kAt = 'news_src_ad_at';
  static const _kDay = 'news_src_ad_day';
  static const _kCount = 'news_src_ad_n';
  static const _minGapMs = 2 * 60 * 1000;
  static const _dailyMax = 8;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Montre la pub plein écran si les règles le permettent, puis rend la main quand elle est fermée.
  static Future<void> beforeSource(BuildContext context) async {
    try {
      final user = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
      if (!AdConfig.current.interstitialEnabled || !AdGate.canShowType(user, 'interstitial')) return;
      final sp = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final sameDay = sp.getString(_kDay) == _today();
      final count = sameDay ? (sp.getInt(_kCount) ?? 0) : 0;
      if (count >= _dailyMax || now - (sp.getInt(_kAt) ?? 0) < _minGapMs) return;

      final closed = Completer<void>();
      void done() {
        if (!closed.isCompleted) closed.complete();
      }

      final shown = await AdmobService.showInterstitialNow(onDismissed: done, onFailed: done);
      if (!shown) return;
      await sp.setInt(_kAt, now);
      await sp.setString(_kDay, _today());
      await sp.setInt(_kCount, count + 1);
      await closed.future.timeout(const Duration(seconds: 120), onTimeout: () {});
    } catch (_) {
      // une pub qui échoue ne doit jamais empêcher d'ouvrir la source
    }
  }
}
