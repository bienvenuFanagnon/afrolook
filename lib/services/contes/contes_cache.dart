import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Copie sur le téléphone d'un conte déjà débloqué : le lecteur le rouvre sans recharger le texte.
class ConteCached {
  const ConteCached({required this.id, required this.rev, required this.lang, required this.until, required this.access, required this.total, required this.free, required this.price, required this.pages, required this.morale});
  final String id, rev, lang, access, morale;
  /// 0 = sans limite (gratuit, débloqué) ; sinon date de fin en millisecondes (conte du jour, pass).
  final int until, total, free, price;
  final List<String> pages;

  bool validFor({required String rev, required String lang}) {
    if (pages.isEmpty || pages.length != total) return false;
    if (rev.isNotEmpty && this.rev != rev) return false; // le texte français a été corrigé depuis
    if (this.lang != lang) return false; // une traduction est arrivée (ou la langue a changé)
    if (until != 0 && until <= DateTime.now().millisecondsSinceEpoch) return false;
    return true;
  }

  Map<String, dynamic> toMap() => {'id': id, 'rev': rev, 'lang': lang, 'until': until, 'access': access, 'total': total, 'free': free, 'price': price, 'pages': pages, 'morale': morale};

  static ConteCached? fromMap(Map m) {
    try {
      return ConteCached(
        id: (m['id'] ?? '').toString(),
        rev: (m['rev'] ?? '').toString(),
        lang: (m['lang'] ?? 'fr').toString(),
        until: (m['until'] as num?)?.toInt() ?? 0,
        access: (m['access'] ?? 'owned').toString(),
        total: (m['total'] as num?)?.toInt() ?? 0,
        free: (m['free'] as num?)?.toInt() ?? 1,
        price: (m['price'] as num?)?.toInt() ?? 0,
        pages: ((m['pages'] as List?) ?? const []).map((e) => e.toString()).toList(),
        morale: (m['morale'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Stockage des contes débloqués dans le dossier de l'application (un petit fichier par conte et par lecteur).
/// Toute erreur de disque est ignorée : sans cache, le conte se charge simplement depuis le serveur.
class ContesCache {
  ContesCache._();
  static const _maxFiles = 80;
  static Directory? _dir;

  static Future<Directory?> _folder() async {
    if (kIsWeb) return null;
    try {
      if (_dir != null) return _dir;
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/contes_cache');
      if (!await d.exists()) await d.create(recursive: true);
      return _dir = d;
    } catch (_) {
      return null;
    }
  }

  static String _name(String uid, String id) => '${uid}_${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.json';

  static Future<ConteCached?> read(String uid, String id) async {
    try {
      final d = await _folder();
      if (d == null) return null;
      final f = File('${d.path}/${_name(uid, id)}');
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString());
      return m is Map ? ConteCached.fromMap(m) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String uid, ConteCached c) async {
    try {
      final d = await _folder();
      if (d == null) return;
      await File('${d.path}/${_name(uid, c.id)}').writeAsString(jsonEncode(c.toMap()), flush: true);
      await _trim(d);
    } catch (_) {}
  }

  static Future<void> remove(String uid, String id) async {
    try {
      final d = await _folder();
      if (d == null) return;
      final f = File('${d.path}/${_name(uid, id)}');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Garde les plus récents : un conte pèse 3 Ko, 80 contes restent sous 300 Ko.
  static Future<void> _trim(Directory d) async {
    try {
      final files = <File, DateTime>{};
      await for (final e in d.list()) {
        if (e is File && e.path.endsWith('.json')) files[e] = (await e.stat()).modified;
      }
      if (files.length <= _maxFiles) return;
      final sorted = files.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      for (final e in sorted.take(files.length - _maxFiles)) {
        await e.key.delete();
      }
    } catch (_) {}
  }
}
