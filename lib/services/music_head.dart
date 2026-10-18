// ignore_for_file: experimental_member_use
// Démarrage éclair de la musique : le DÉBUT de chaque titre auquel la personne a droit est gardé d'avance sur son téléphone.
//
// Pourquoi : au premier « Lecture » d'un titre complet, il faut demander un lien d'écoute au serveur, attendre qu'il soit prêt, puis
// télécharger. Avec le début déjà là, le son part tout de suite ; le lien et la suite arrivent pendant qu'on écoute.
//
// Protection (même principe que les titres téléchargés, voir offline_music_service.dart) :
// - seulement pour les titres qu'on peut écouter en entier (acheté, gratuit, à soi) ; jamais le début d'un titre payant non acheté ;
// - chiffré (AES-256-GCM) avec une clé gardée dans le coffre du téléphone (Keystore / Keychain), fichier .bin au nom sans rapport,
//   dans l'espace privé de l'application (invisible dans « Fichiers » et la galerie) ;
// - déchiffré en mémoire seulement, jamais écrit en clair ; effacé à la déconnexion ;
// - petit : 640 Ko par titre (environ 40 secondes), 40 titres au plus, les plus anciens sont remplacés.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/audio_format.dart';
import '../utils/fnv.dart';
import 'offline_music_service.dart';

/// Début d'un titre, déchiffré en mémoire.
class MusicHeadData {
  const MusicHeadData(this.bytes, this.total, this.kind);
  final Uint8List bytes;

  /// Taille totale du fichier (octets).
  final int total;
  final AudioKind kind;
}

class MusicHead {
  MusicHead._();

  static const int headBytes = 640 * 1024;
  static const int maxHeads = 40;

  /// Au plus ce nombre de débuts préparés par lancement de l'application (limite la consommation de données).
  static const int maxPerSession = 24;
  static const _magic = [0x41, 0x46, 0x48, 0x31]; // « AFH1 »

  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static bool get supported => OfflineMusic.supported;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static final Set<String> _have = {};
  static final Set<String> _busy = {};
  static final List<String> _queue = [];
  static bool _running = false;
  static int _prepared = 0;

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/afrolook_h');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _fileName(String uid, String soundId) => '${fnv63('h$uid$soundId').padLeft(10, '0')}.bin';

  static Future<List<int>> _key() async {
    var b64 = await _store.read(key: 'mh_key');
    if (b64 == null || b64.length < 40) {
      final r = Random.secure();
      b64 = base64Encode(List<int>.generate(32, (_) => r.nextInt(256)));
      await _store.write(key: 'mh_key', value: b64);
    }
    return base64Decode(b64);
  }

  /// Le début de ce titre est-il déjà là (vérification rapide, sans lecture du disque après la première fois) ?
  static bool has(String soundId) => _have.contains(soundId);

  /// Début déchiffré du titre, ou null s'il n'est pas (encore) sur l'appareil.
  static Future<MusicHeadData?> read(String soundId) async {
    final uid = _uid;
    if (!supported || uid == null) return null;
    try {
      final f = File('${(await _dir()).path}/${_fileName(uid, soundId)}');
      if (!await f.exists()) return null;
      final raw = await f.readAsBytes();
      final data = await decode(raw, await _key());
      if (data == null) {
        await f.delete().catchError((_) => f);
        return null;
      }
      _have.add(soundId);
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Prépare le début de [soundId] en arrière-plan (une file, un titre à la fois). [urlOf] donne le lien d'écoute du titre complet.
  /// À n'appeler que pour un titre dont la personne a le droit d'écouter la version complète.
  static void prefetch(String soundId, Future<String?> Function(String id) urlOf) {
    if (!supported || _uid == null) return;
    if (_have.contains(soundId) || _busy.contains(soundId) || _queue.contains(soundId)) return;
    if (_prepared >= maxPerSession) return;
    _queue.add(soundId);
    unawaited(_drain(urlOf));
  }

  static Future<void> _drain(Future<String?> Function(String id) urlOf) async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty && _prepared < maxPerSession) {
        final id = _queue.removeAt(0);
        _busy.add(id);
        try {
          if (await read(id) != null) continue;
          final url = await urlOf(id);
          if (url == null) continue;
          if (await _fetch(id, url)) _prepared++;
        } catch (_) {
        } finally {
          _busy.remove(id);
        }
      }
    } finally {
      _running = false;
    }
  }

  static Future<bool> _fetch(String soundId, String url) async {
    final uid = _uid;
    if (uid == null) return false;
    final res = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Range': 'bytes=0-${headBytes - 1}'},
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (s) => s == 200 || s == 206,
      ),
    );
    var bytes = Uint8List.fromList(res.data ?? const []);
    if (bytes.length < 4000) return false;
    final total = totalOf(res.headers.value('content-range'), bytes.length);
    // Le serveur a ignoré la demande partielle et envoyé tout le fichier : on n'en garde que le début
    if (res.statusCode == 200 && bytes.length > headBytes) bytes = Uint8List.sublistView(bytes, 0, headBytes);
    final kind = AudioKind.sniffBytes(bytes);
    final sealed = await compute(_sealJob, _Seal(bytes, await _key()));
    final out = encode(sealed, total, kind);
    final dir = await _dir();
    await File('${dir.path}/${_fileName(uid, soundId)}').writeAsBytes(out, flush: true);
    _have.add(soundId);
    unawaited(_trim(dir));
    return true;
  }

  /// Taille totale du fichier d'après « Content-Range: bytes 0-655359/4812345 » (sinon la taille reçue si le fichier est entier).
  @visibleForTesting
  static int totalOf(String? contentRange, int received) {
    if (contentRange != null) {
      final m = RegExp(r'/(\d+)\s*$').firstMatch(contentRange);
      if (m != null) return int.parse(m.group(1)!);
    }
    return received;
  }

  static Future<Uint8List> _sealJob(_Seal j) => OfflineMusic.seal(j.data, j.key);

  /// En-tête : « AFH1 », taille totale (4 octets), format (1 octet), puis le début chiffré.
  @visibleForTesting
  static Uint8List encode(Uint8List sealed, int total, AudioKind kind) {
    final out = BytesBuilder();
    out.add(_magic);
    out.add((ByteData(4)..setUint32(0, total)).buffer.asUint8List());
    out.addByte(kind.index);
    out.add(sealed);
    return out.toBytes();
  }

  @visibleForTesting
  static Future<MusicHeadData?> decode(Uint8List raw, List<int> key) async {
    if (raw.length < 9 + 4 + 12 + 16) return null;
    for (var i = 0; i < 4; i++) {
      if (raw[i] != _magic[i]) return null;
    }
    final total = ByteData.sublistView(raw, 4, 8).getUint32(0);
    final kindIndex = raw[8];
    if (kindIndex >= AudioKind.values.length) return null;
    final clear = await OfflineMusic.open(Uint8List.sublistView(raw, 9), key);
    if (clear == null) return null;
    return MusicHeadData(clear, total, AudioKind.values[kindIndex]);
  }

  static Future<void> _trim(Directory d) async {
    try {
      final files = d.listSync().whereType<File>().where((f) => f.path.endsWith('.bin')).toList();
      if (files.length <= maxHeads) return;
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      for (final f in files.take(files.length - maxHeads)) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  /// Déconnexion : tous les débuts et la clé sont effacés de l'appareil.
  static Future<void> purgeAll() async {
    _have.clear();
    _queue.clear();
    _prepared = 0;
    try {
      final d = await _dir();
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
    try {
      await _store.delete(key: 'mh_key');
    } catch (_) {}
  }
}

class _Seal {
  const _Seal(this.data, this.key);
  final Uint8List data;
  final List<int> key;
}

/// Source audio « début local + suite réseau » : le lecteur la voit comme un seul fichier. Les premiers octets viennent de l'appareil
/// (départ instantané), le reste est demandé au réseau par morceaux (Range) dès que le lecteur en a besoin.
class HeadStartSource extends StreamAudioSource {
  HeadStartSource({required this.head, required this.total, required this.kind, required this.urlProvider, super.tag});

  final Uint8List head;
  final int total;
  final AudioKind kind;

  /// Lien d'écoute du titre complet ; demandé une seule fois, au moment où la suite devient nécessaire.
  final Future<String?> Function() urlProvider;
  Future<String?>? _url;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = min(end ?? total, total);
    final stream = e <= head.length ? Stream<List<int>>.value(head.sublist(s, e)) : _joined(s, e);
    return StreamAudioResponse(sourceLength: total, contentLength: e - s, offset: s, stream: stream, contentType: kind.mime);
  }

  Stream<List<int>> _joined(int s, int e) async* {
    var from = s;
    if (from < head.length) {
      yield head.sublist(from);
      from = head.length;
    }
    yield* _network(from, e, retry: true);
  }

  Stream<List<int>> _network(int from, int to, {required bool retry}) async* {
    final url = await (_url ??= urlProvider());
    if (url == null) throw StateError('lien d’écoute indisponible');
    var pos = from;
    try {
      final r = await Dio().get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=$from-${to - 1}'},
          validateStatus: (s) => s == 200 || s == 206,
        ),
      );
      var skip = r.statusCode == 200 ? from : 0; // le serveur a renvoyé le fichier depuis le début
      await for (final chunk in r.data!.stream) {
        var c = chunk;
        if (skip > 0) {
          if (c.length <= skip) {
            skip -= c.length;
            continue;
          }
          c = c.sublist(skip);
          skip = 0;
        }
        pos += c.length;
        yield c;
      }
    } on DioException {
      // Lien périmé (10 minutes) : on en redemande un, une seule fois, et on reprend là où on s'est arrêté
      if (!retry || pos >= to) rethrow;
      _url = null;
      yield* _network(pos, to, retry: false);
    }
  }
}
