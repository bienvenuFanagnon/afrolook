import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coin_pack.dart';

class QuickGiftService {
  static const _recentKey = 'quick_gift_recent_v1';
  static const _pinnedKey = 'quick_gift_pinned_v1';
  static const _maxRecent = 10;
  static const _maxPinned = 3;

  static String _packKey(CoinPack p) => '${p.icon}||${p.label}||${p.coins}';

  static Map<String, dynamic> _packToMap(CoinPack p) =>
      {'icon': p.icon, 'label': p.label, 'coins': p.coins, 'priceFcfa': p.priceFcfa};

  static CoinPack? _packFromMap(Map<String, dynamic> m) {
    try {
      final icon = m['icon'] as String;
      final label = m['label'] as String;
      final coins = m['coins'] as int;
      final priceFcfa = (m['priceFcfa'] as num).toDouble();
      return CoinPack(coins: coins, priceFcfa: priceFcfa, icon: icon, label: label);
    } catch (_) {
      return null;
    }
  }

  static Future<void> recordRecentGift(CoinPack pack) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentKey) ?? [];
    final key = _packKey(pack);
    raw.removeWhere((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return _packKey(_packFromMap(m) ?? pack) == key;
      } catch (_) {
        return false;
      }
    });
    raw.insert(0, jsonEncode(_packToMap(pack)));
    if (raw.length > _maxRecent) raw.removeRange(_maxRecent, raw.length);
    await prefs.setStringList(_recentKey, raw);
  }

  static Future<List<CoinPack>> getRecentGifts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentKey) ?? [];
    return raw
        .map((s) {
          try {
            return _packFromMap(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<CoinPack>()
        .toList();
  }

  static Future<void> pinGift(CoinPack pack) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pinnedKey) ?? [];
    final key = _packKey(pack);
    raw.removeWhere((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return _packKey(_packFromMap(m) ?? pack) == key;
      } catch (_) {
        return false;
      }
    });
    raw.insert(0, jsonEncode(_packToMap(pack)));
    if (raw.length > _maxPinned) raw.removeRange(_maxPinned, raw.length);
    await prefs.setStringList(_pinnedKey, raw);
  }

  static Future<void> unpinGift(CoinPack pack) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pinnedKey) ?? [];
    final key = _packKey(pack);
    raw.removeWhere((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return _packKey(_packFromMap(m) ?? pack) == key;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_pinnedKey, raw);
  }

  static Future<List<CoinPack>> getPinnedGifts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pinnedKey) ?? [];
    return raw
        .map((s) {
          try {
            return _packFromMap(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<CoinPack>()
        .toList();
  }

  static Future<bool> isGiftPinned(CoinPack pack) async {
    final pinned = await getPinnedGifts();
    final key = _packKey(pack);
    return pinned.any((p) => _packKey(p) == key);
  }

  /// Returns up to 3 slots: pinned first, then recent (no duplicates).
  /// Falls back to 3 default gifts when history is empty.
  static Future<List<({CoinPack pack, bool pinned})>> getShortcuts() async {
    final pinned = await getPinnedGifts();
    final recent = await getRecentGifts();

    final result = <({CoinPack pack, bool pinned})>[];
    final seen = <String>{};

    for (final p in pinned) {
      final k = _packKey(p);
      if (!seen.contains(k)) {
        result.add((pack: p, pinned: true));
        seen.add(k);
      }
    }

    for (final r in recent) {
      if (result.length >= 3) break;
      final k = _packKey(r);
      if (!seen.contains(k)) {
        result.add((pack: r, pinned: false));
        seen.add(k);
      }
    }

    if (result.isEmpty) {
      // Default suggestions when no history
      final defaults = [
        CoinPack.giftPacks.firstWhere((p) => p.icon == '🔥'),
        CoinPack.giftPacks.firstWhere((p) => p.icon == '💎'),
        CoinPack.giftPacks.firstWhere((p) => p.icon == '👑'),
      ];
      for (final d in defaults) {
        result.add((pack: d, pinned: false));
      }
    }

    return result.take(3).toList();
  }
}
