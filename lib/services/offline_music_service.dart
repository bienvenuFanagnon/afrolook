// Titres téléchargés « façon YouTube » : le fichier n'existe jamais en clair sur le téléphone.
//
// - Le serveur délivre une licence (30 jours, 3 appareils, 20 téléchargements/jour) avec une clé propre à la personne et à l'appareil.
// - Le titre est chiffré (AES-256-GCM) et rangé dans l'espace privé de l'application (dossier caché, nom sans rapport, extension .bin) :
//   invisible dans « Fichiers », la galerie, les récents, et exclu des sauvegardes.
// - La clé est gardée dans le coffre du téléphone (Keystore / Keychain, non transférable).
// - À l'écoute, le titre est déchiffré en mémoire seulement ; la licence se renouvelle toute seule dès que le téléphone est en ligne,
//   et le titre est effacé si la personne n'y a plus droit (retiré, suspendu).

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../pages/studio/artist_sound_common.dart';

class OfflineResult {
  const OfflineResult.ok() : ok = true, message = null, needsPurchase = false;
  const OfflineResult.fail(this.message, {this.needsPurchase = false}) : ok = false;
  final bool ok;
  final String? message;
  final bool needsPurchase;
}

class OfflineMusic {
  OfflineMusic._();

  /// Titres disponibles hors ligne pour la personne connectée.
  static final ValueNotifier<Set<String>> ids = ValueNotifier<Set<String>>(<String>{});

  /// Pas de téléchargement protégé sur le web.
  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _magic = [0x41, 0x46, 0x4d, 0x31]; // « AFM1 »
  static const _renewBeforeDays = 7;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static String _metaKey(String uid, String soundId) => 'om_${uid}_$soundId';

  static Future<String> deviceId() async {
    var id = await _store.read(key: 'om_device');
    if (id == null || id.length < 8) {
      final r = Random.secure();
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      id = List.generate(28, (_) => chars[r.nextInt(chars.length)]).join();
      await _store.write(key: 'om_device', value: id);
    }
    return id;
  }

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/afrolook_m');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Relit la liste des titres téléchargés par la personne connectée.
  static Future<void> refresh() async {
    final uid = _uid;
    if (!supported || uid == null) {
      ids.value = <String>{};
      return;
    }
    try {
      final all = await _store.readAll();
      final prefix = 'om_${uid}_';
      final out = <String>{};
      for (final k in all.keys) {
        if (k.startsWith(prefix)) out.add(k.substring(prefix.length));
      }
      ids.value = out;
    } catch (_) {}
  }

  static bool has(String soundId) => ids.value.contains(soundId);

  static String _friendly(FirebaseFunctionsException e) {
    final m = '${e.message}';
    if (m.contains('ACHAT_REQUIS')) return 'Achète ce titre pour le télécharger.';
    if (m.contains('APPAREILS')) return 'Ce titre est déjà téléchargé sur 3 appareils. Supprime-le d’un autre appareil pour continuer.';
    if (m.contains('LIMITE_JOUR')) return 'Limite de téléchargements du jour atteinte. Reviens demain.';
    if (m.contains('RETIRE')) return 'Ce titre n’est plus disponible.';
    if (e.code == 'unauthenticated') return 'Connecte-toi pour télécharger.';
    return 'Téléchargement impossible pour le moment.';
  }

  /// Télécharge, chiffre et range le titre. [onProgress] : 0 à 1.
  static Future<OfflineResult> download(String soundId, {void Function(double)? onProgress}) async {
    final uid = _uid;
    if (!supported) return const OfflineResult.fail('Le téléchargement n’est disponible que dans l’application mobile.');
    if (uid == null) return const OfflineResult.fail('Connecte-toi pour télécharger.');
    try {
      final lic = Map<String, dynamic>.from((await FirebaseFunctions.instance.httpsCallable('musicLicense').call({'soundId': soundId, 'deviceId': await deviceId()})).data as Map);
      final url = lic['url'] as String?;
      final keyB64 = lic['key'] as String?;
      if (url == null || keyB64 == null) return const OfflineResult.fail('Téléchargement impossible pour le moment.');

      final res = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 5)),
        onReceiveProgress: (r, t) {
          if (t > 0) onProgress?.call((r / t) * 0.8);
        },
      );
      final plain = Uint8List.fromList(res.data ?? const []);
      if (plain.length < 1000) return const OfflineResult.fail('Fichier reçu incomplet. Réessaie.');
      onProgress?.call(0.85);

      final sealed = await compute(_seal, _Job(plain, base64Decode(keyB64)));
      final fileName = '${_hash('$uid$soundId')}.bin';
      final dir = await _dir();
      await File('${dir.path}/$fileName').writeAsBytes(sealed, flush: true);
      await _store.write(
        key: _metaKey(uid, soundId),
        value: jsonEncode({
          'key': keyB64,
          'file': fileName,
          'expiresAt': lic['expiresAt'],
          'title': lic['title'],
          'artist': lic['artist'],
          'cover': lic['coverImageUrl'],
        }),
      );
      onProgress?.call(1);
      await refresh();
      return const OfflineResult.ok();
    } on FirebaseFunctionsException catch (e) {
      return OfflineResult.fail(_friendly(e), needsPurchase: '${e.message}'.contains('ACHAT_REQUIS'));
    } on DioException {
      return const OfflineResult.fail('Téléchargement interrompu. Vérifie ta connexion.');
    } catch (_) {
      return const OfflineResult.fail('Téléchargement impossible pour le moment.');
    }
  }

  static String _hash(String s) {
    // Nom de fichier sans rapport avec le titre (empreinte simple, sans importance de sécurité)
    var h = 0xcbf29ce484222325;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return h.toRadixString(36).padLeft(10, '0');
  }

  /// Efface le titre de cet appareil.
  static Future<void> remove(String soundId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final raw = await _store.read(key: _metaKey(uid, soundId));
      if (raw != null) {
        final f = (jsonDecode(raw) as Map)['file'] as String?;
        if (f != null) {
          final file = File('${(await _dir()).path}/$f');
          if (await file.exists()) await file.delete();
        }
      }
      await _store.delete(key: _metaKey(uid, soundId));
    } catch (_) {}
    await refresh();
  }

  /// Lit un titre téléchargé : renouvelle la licence si besoin, déchiffre en mémoire et joue. Renvoie un message en cas d'échec.
  static Future<String?> play(String soundId, {String? title, String? key}) async {
    final uid = _uid;
    if (uid == null) return 'Connecte-toi pour écouter tes titres téléchargés.';
    try {
      final raw = await _store.read(key: _metaKey(uid, soundId));
      if (raw == null) {
        await refresh();
        return 'Ce titre n’est plus téléchargé sur cet appareil.';
      }
      var meta = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final now = DateTime.now().millisecondsSinceEpoch;
      final left = ((meta['expiresAt'] as num?)?.toInt() ?? 0) - now;
      if (left < _renewBeforeDays * 24 * 3600 * 1000) {
        try {
          final r = Map<String, dynamic>.from((await FirebaseFunctions.instance.httpsCallable('musicLicense').call({'soundId': soundId, 'deviceId': await deviceId(), 'renew': true})).data as Map);
          meta['expiresAt'] = r['expiresAt'];
          meta['key'] = r['key'] ?? meta['key'];
          await _store.write(key: _metaKey(uid, soundId), value: jsonEncode(meta));
        } on FirebaseFunctionsException catch (e) {
          final m = '${e.message}';
          // Plus de droit sur ce titre : on l'efface de l'appareil. Une simple panne réseau n'efface rien.
          if (m.contains('ACHAT_REQUIS') || m.contains('RETIRE') || e.code == 'not-found') {
            await remove(soundId);
            return 'Ce titre n’est plus disponible : il a été retiré de ton appareil.';
          }
          if (left <= 0) return 'Licence expirée. Connecte-toi à internet pour la renouveler.';
        } catch (_) {
          if (left <= 0) return 'Licence expirée. Connecte-toi à internet pour la renouveler.';
        }
      }
      final file = File('${(await _dir()).path}/${meta['file']}');
      if (!await file.exists()) {
        await remove(soundId);
        return 'Le fichier est introuvable : retélécharge ce titre.';
      }
      final plain = await compute(_open, _Job(await file.readAsBytes(), base64Decode(meta['key'] as String)));
      if (plain == null) {
        await remove(soundId);
        return 'Le fichier est abîmé : retélécharge ce titre.';
      }
      final t = (meta['title'] as String?) ?? title ?? 'Titre';
      final k = key ?? 'lib_$soundId';
      final ok = await SoundPreview.playBytes(
        k,
        plain,
        meta: NowPlaying(key: k, title: t, subtitle: (meta['artist'] as String?) ?? 'Hors ligne', coverUrl: meta['cover'] as String?),
      );
      return ok ? null : 'Lecture impossible.';
    } catch (_) {
      return 'Lecture impossible.';
    }
  }

  // ── Chiffrement (exécuté dans un autre processus léger pour ne pas figer l'écran) ──
  @visibleForTesting
  static Future<Uint8List> seal(Uint8List data, List<int> key) => _seal(_Job(data, key));

  @visibleForTesting
  static Future<Uint8List?> open(Uint8List data, List<int> key) => _open(_Job(data, key));

  static Future<Uint8List> _seal(_Job j) async {
    final algo = AesGcm.with256bits();
    final box = await algo.encrypt(j.data, secretKey: SecretKey(j.key), aad: _magic);
    return Uint8List.fromList([..._magic, ...box.concatenation()]);
  }

  static Future<Uint8List?> _open(_Job j) async {
    try {
      if (j.data.length < 4 + 12 + 16) return null;
      for (var i = 0; i < 4; i++) {
        if (j.data[i] != _magic[i]) return null;
      }
      final box = SecretBox.fromConcatenation(j.data.sublist(4), nonceLength: 12, macLength: 16);
      final clear = await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(j.key), aad: _magic);
      return Uint8List.fromList(clear);
    } catch (_) {
      return null;
    }
  }
}

class _Job {
  const _Job(this.data, this.key);
  final Uint8List data;
  final List<int> key;
}
