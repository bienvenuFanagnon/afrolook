import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'key_change_tracker.dart';

/// Chiffrement de bout en bout des messages TEXTE des groupes de discussion (fiche 34, §3).
///
/// Principe :
/// - une clé de groupe AES-256 par ÉPOQUE (epoch). L'API ne la voit jamais : elle ne garde que des ENVELOPPES (la clé chiffrée pour un membre).
/// - enveloppe pour un membre R, posée par un administrateur A : X25519(privée de A, publique de R) puis HKDF-SHA256, puis AES-256-GCM.
///   Le contexte (groupe, époque, A, R) est lié à la clé dérivée ET aux données authentifiées : une enveloppe ne peut être ni déplacée ni rejouée ailleurs.
///   R ouvre l'enveloppe avec X25519(privée de R, publique de A) : la clé publique de A vient de l'annuaire de l'API (même annuaire que les chats 1 à 1).
/// - message : chaque champ texte est chiffré en AES-256-GCM avec la clé de l'époque courante, données authentifiées = groupe, époque, identifiant du
///   message et nom du champ (un message ne peut pas être déplacé vers un autre groupe, une autre époque ou un autre message). Le document Firestore
///   porte `is_encrypted: true` et `key_epoch`.
/// - rotation : après le départ ou l'exclusion d'un membre, l'API marque `rotation_required`; l'appareil d'un administrateur génère une nouvelle clé
///   (époque + 1) et la distribue aux membres restants SEULEMENT. Les anciens messages restent lisibles avec les anciennes clés conservées.
/// - compatibilité : un message sans `is_encrypted: true` + `key_epoch` est affiché tel quel (anciens messages en clair). Un message chiffré dont la clé
///   est indisponible est affiché « Message chiffré, clé indisponible » (jamais d'exception).
///
/// Les photos, vidéos et audios ne sont PAS chiffrés (étape distincte, fiche 34) : seuls le texte, la légende, la citation d'une réponse et l'aperçu de
/// lien d'un message le sont.
class GroupCryptoService {
  GroupCryptoService({
    required this.backend,
    required this.identity,
    required this.store,
    KeyChangeTracker? tracker,
  }) : tracker = tracker ?? KeyChangeTracker(MemoryKeyValueStore());

  final GroupKeyBackend backend;
  final GroupKeyIdentity identity;
  final GroupKeyStore store;
  final KeyChangeTracker tracker;

  /// Texte affiché à la place d'un message chiffré dont la clé n'est pas disponible.
  static const String lockedText = 'Message chiffré, clé indisponible';

  /// Préfixe d'un champ de message chiffré.
  static const String fieldPrefix = 'genc:v1:';

  /// Préfixe d'une enveloppe de clé de groupe.
  static const String envelopePrefix = 'ge1:';

  /// Champs de message susceptibles d'être chiffrés (le nom est dans les données authentifiées).
  static const String fMessage = 'message';
  static const String fCaption = 'caption';
  static const String fReply = 'reply_to_message';
  static const String fLinkPreview = 'link_preview_enc';

  static const int _maxEnvelopesPerCall = 200;
  static const int _maxAutoEnableMembers = 50;

  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Clés de groupe ouvertes : `moi|groupe` -> époque -> clé.
  final Map<String, Map<int, SecretKey>> _keys = {};
  final Map<String, GroupKeyState> _states = {};
  final Map<String, Future<GroupKeyState>> _inFlight = {};
  final Set<String> _publishedFor = {};
  final Map<String, int> _myKeyVersion = {};

  static String _ck(String me, String groupId) => '$me|$groupId';

  // ─────────────────────────────────────────────────────────────────────────────────────────────
  // Règle d'activation
  // ─────────────────────────────────────────────────────────────────────────────────────────────

  /// Active-t-on le chiffrement automatiquement pour ce groupe ? (fiche 34, §3.6) Par défaut : groupes privés ou payants et petits groupes (50 membres
  /// ou moins) ; jamais les groupes officiels (grandes audiences, modération par l'équipe) ; jamais un groupe déjà chiffré.
  static bool shouldAutoEnable({required int memberCount, required bool isPrivate, required int priceCoins, required bool isOfficial, required int currentEpoch}) {
    if (currentEpoch > 0 || isOfficial) return false;
    return isPrivate || priceCoins > 0 || memberCount <= _maxAutoEnableMembers;
  }

  // ─────────────────────────────────────────────────────────────────────────────────────────────
  // Lecture de l'état et ouverture des enveloppes
  // ─────────────────────────────────────────────────────────────────────────────────────────────

  /// Dernier état connu du groupe (null tant qu'il n'a pas été chargé).
  GroupKeyState? stateOf(String groupId, String me) => _states[_ck(me, groupId)];

  /// Charge l'état une seule fois (appels simultanés regroupés). Les échecs réseau ne sont pas mémorisés.
  Future<GroupKeyState> ensureLoaded(String groupId, String me) {
    final k = _ck(me, groupId);
    final known = _states[k];
    if (known != null) return Future.value(known);
    return _inFlight[k] ??= refresh(groupId, me).whenComplete(() {
      _inFlight.remove(k);
    });
  }

  /// Relit les enveloppes de l'API, ouvre celles qu'on n'a pas encore, conserve les clés obtenues. N'écrit rien dans l'API sauf la publication de MA clé
  /// publique si elle manque dans l'annuaire (sans quoi aucun administrateur ne pourrait m'envoyer la clé du groupe).
  Future<GroupKeyState> refresh(String groupId, String me) async {
    final k = _ck(me, groupId);
    final cache = _keys.putIfAbsent(k, () => {});
    if (cache.isEmpty) {
      try {
        (await store.load(me, groupId)).forEach((e, b) => cache[e] = SecretKey(b));
      } catch (_) {}
    }
    var mismatch = false;
    try {
      await _ensureMyKeyPublished(me);
    } on GroupKeyIdentityMismatch {
      mismatch = true;
    } catch (e) {
      debugPrint('GroupCryptoService: publication de ma clé impossible ($e)');
    }

    final Map<String, dynamic> data;
    try {
      data = await backend.fetchKeys(groupId);
    } on GroupKeyApiError catch (e) {
      if (e.status == 404) {
        // pas (ou plus) membre : seules les clés déjà conservées sur l'appareil servent
        final st = GroupKeyState(encrypted: cache.isNotEmpty, epoch: cache.isEmpty ? 0 : (cache.keys.toList()..sort()).last, rotationRequired: false, openedEpochs: _sorted(cache.keys), unreadableEpochs: const [], pendingMembers: const [], changedKeyUsers: const [], hasCurrentKey: cache.isNotEmpty, identityMismatch: mismatch, isMember: false);
        return _states[k] = st;
      }
      rethrow;
    }

    final epoch = _asInt(data['epoch']);
    final encrypted = data['encrypted'] == true && epoch > 0;
    final envelopes = (data['envelopes'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final unreadable = <int>[];

    // Clés publiques ACTUELLES des administrateurs qui m'ont envoyé des enveloppes : servent à ouvrir les nouvelles, et à avertir si l'une a changé.
    final toOpen = envelopes.where((e) => !cache.containsKey(_asInt(e['epoch']))).toList();
    final wrapperIds = envelopes.map((e) => '${e['wrapped_by']}').where((id) => id != me && id.isNotEmpty).toSet();
    final wrapperKeys = wrapperIds.isEmpty ? <String, Map<String, dynamic>>{} : await _safePublicKeys(wrapperIds);
    for (final id in wrapperIds) {
      final wk = wrapperKeys[id];
      if (wk != null) await tracker.observe(me, id, '${wk['public_key']}', _asInt(wk['version']));
    }
    final changed = await tracker.warningsAmong(me, wrapperIds);
    if (toOpen.isNotEmpty) {
      final pair = await identity.keyPair(me);
      for (final e in toOpen) {
        final ep = _asInt(e['epoch']);
        final wrapper = '${e['wrapped_by']}';
        try {
          final List<int> theirPub;
          if (wrapper == me) {
            theirPub = (await pair.extractPublicKey()).bytes;
          } else {
            final wk = wrapperKeys[wrapper];
            if (wk == null) throw const FormatException('clé publique du posteur introuvable');
            theirPub = base64Decode('${wk['public_key']}');
          }
          final keyBytes = await openEnvelope('${e['envelope']}', myPair: pair, theirPublic: theirPub, groupId: groupId, epoch: ep, wrapperId: wrapper, recipientId: me);
          cache[ep] = SecretKey(keyBytes);
          try {
            await store.save(me, groupId, ep, keyBytes);
          } catch (_) {}
        } catch (err) {
          debugPrint('GroupCryptoService: enveloppe de l\'époque $ep illisible ($err)');
          unreadable.add(ep);
        }
      }
    }
    // une clé gardée sur l'appareil pour une époque dont l'enveloppe n'est plus servie reste utilisable
    final pending = ((data['pending_members'] as List?) ?? const []).map((e) => '$e').toList();
    final st = GroupKeyState(
      encrypted: encrypted || cache.isNotEmpty,
      epoch: encrypted ? epoch : (cache.isEmpty ? 0 : (cache.keys.toList()..sort()).last),
      rotationRequired: data['rotation_required'] == true,
      openedEpochs: _sorted(cache.keys),
      unreadableEpochs: unreadable,
      pendingMembers: pending,
      changedKeyUsers: changed,
      hasCurrentKey: encrypted ? cache.containsKey(epoch) : true,
      identityMismatch: mismatch,
      isMember: true,
    );
    return _states[k] = st;
  }

  // ─────────────────────────────────────────────────────────────────────────────────────────────
  // Côté administrateur : création, rotation, distribution
  // ─────────────────────────────────────────────────────────────────────────────────────────────

  /// À appeler quand le chat s'ouvre sur l'appareil d'un administrateur ou du propriétaire :
  /// - groupe non chiffré : crée l'époque 1 si [mayEnable] ;
  /// - changement de clé exigé par l'API (départ ou exclusion) : nouvelle époque pour les membres restants ;
  /// - nouveaux membres sans enveloppe : leur envoie la clé de l'époque courante.
  Future<GroupSyncReport> syncAsAdmin(String groupId, String me, {bool mayEnable = false}) async {
    var st = await refresh(groupId, me);
    if (!st.isMember) return GroupSyncReport(st);
    if (!st.encrypted) {
      if (!mayEnable) return GroupSyncReport(st);
      return _distributeNew(groupId, me, 1, enabled: true);
    }
    if (st.rotationRequired) return _distributeNew(groupId, me, st.epoch + 1, rotated: true);
    if (st.pendingMembers.isNotEmpty && st.hasCurrentKey) return _distributeToPending(groupId, me, st);
    return GroupSyncReport(st);
  }

  /// Renouvellement volontaire de la clé (par exemple si un membre a perdu la sienne) : nouvelle époque pour les membres actuels.
  Future<GroupSyncReport> rotate(String groupId, String me) async {
    final st = await refresh(groupId, me);
    if (!st.encrypted) return _distributeNew(groupId, me, 1, enabled: true);
    return _distributeNew(groupId, me, st.epoch + 1, rotated: true);
  }

  Future<GroupSyncReport> _distributeNew(String groupId, String me, int epoch, {bool enabled = false, bool rotated = false}) async {
    final myVersion = await _ensureMyKeyPublished(me);
    final members = await backend.memberIds(groupId);
    final ordered = <String>[me, ...members.where((m) => m != me)]; // mon enveloppe en tête : elle fixe l'époque dès le premier envoi
    final dir = await _safePublicKeys(ordered);
    final pair = await identity.keyPair(me);
    final groupKey = SecretKeyData.random(length: 32).bytes;
    final envelopes = <Map<String, dynamic>>[];
    final missing = <String>[];
    final changed = <String>[];
    for (final uid in ordered) {
      final entry = uid == me ? {'public_key': base64Encode((await pair.extractPublicKey()).bytes), 'version': myVersion} : dir[uid];
      if (entry == null) {
        missing.add(uid);
        continue;
      }
      if (uid != me && await tracker.observe(me, uid, '${entry['public_key']}', _asInt(entry['version'])) == KeyCheck.changed) changed.add(uid);
      envelopes.add({
        'user_id': uid,
        'envelope': await wrapKey(groupKey, myPair: pair, theirPublic: base64Decode('${entry['public_key']}'), groupId: groupId, epoch: epoch, wrapperId: me, recipientId: uid),
        'wrapper_key_version': myVersion,
      });
    }
    if (envelopes.isEmpty || envelopes.first['user_id'] != me) {
      throw const GroupKeyUnavailable('Votre clé de chiffrement n\'est pas encore publiée.');
    }
    for (var i = 0; i < envelopes.length; i += _maxEnvelopesPerCall) {
      await backend.postEnvelopes(groupId, epoch, envelopes.sublist(i, (i + _maxEnvelopesPerCall).clamp(0, envelopes.length)));
    }
    // La clé retenue est TOUJOURS celle de l'enveloppe relue : si un autre administrateur a créé la même époque avant nous, la sienne l'emporte.
    _keys[_ck(me, groupId)]?.remove(epoch);
    final st = await refresh(groupId, me);
    return GroupSyncReport(st, enabled: enabled, rotated: rotated, distributed: envelopes.length, missingKeys: missing, changedKeyUsers: changed);
  }

  Future<GroupSyncReport> _distributeToPending(String groupId, String me, GroupKeyState st) async {
    final key = _keys[_ck(me, groupId)]?[st.epoch];
    if (key == null) return GroupSyncReport(st);
    final myVersion = await _ensureMyKeyPublished(me);
    final pair = await identity.keyPair(me);
    final keyBytes = await key.extractBytes();
    final dir = await _safePublicKeys(st.pendingMembers);
    final envelopes = <Map<String, dynamic>>[];
    final missing = <String>[];
    final changed = <String>[];
    for (final uid in st.pendingMembers) {
      final entry = dir[uid];
      if (entry == null) {
        missing.add(uid);
        continue;
      }
      if (await tracker.observe(me, uid, '${entry['public_key']}', _asInt(entry['version'])) == KeyCheck.changed) changed.add(uid);
      envelopes.add({
        'user_id': uid,
        'envelope': await wrapKey(keyBytes, myPair: pair, theirPublic: base64Decode('${entry['public_key']}'), groupId: groupId, epoch: st.epoch, wrapperId: me, recipientId: uid),
        'wrapper_key_version': myVersion,
      });
    }
    for (var i = 0; i < envelopes.length; i += _maxEnvelopesPerCall) {
      await backend.postEnvelopes(groupId, st.epoch, envelopes.sublist(i, (i + _maxEnvelopesPerCall).clamp(0, envelopes.length)));
    }
    final fresh = envelopes.isEmpty ? st : await refresh(groupId, me);
    return GroupSyncReport(fresh, distributed: envelopes.length, missingKeys: missing, changedKeyUsers: changed);
  }

  // ─────────────────────────────────────────────────────────────────────────────────────────────
  // Messages
  // ─────────────────────────────────────────────────────────────────────────────────────────────

  /// Chiffre les champs texte d'un document de message prêt à être écrit sur Firebase, si le groupe est chiffré.
  /// Groupe non chiffré : le document est rendu tel quel. Groupe chiffré mais clé de l'époque courante indisponible (ou état inconnu) :
  /// lève [GroupKeyUnavailable] — l'appelant DOIT refuser l'envoi, jamais écrire en clair.
  Future<Map<String, dynamic>> sealMessage(String groupId, String me, String msgId, Map<String, dynamic> doc) async {
    final GroupKeyState st;
    try {
      st = await ensureLoaded(groupId, me);
    } catch (e) {
      throw GroupKeyUnavailable('Impossible de vérifier le chiffrement du groupe ($e).');
    }
    if (!st.encrypted) return doc;
    final key = _keys[_ck(me, groupId)]?[st.epoch];
    if (!st.hasCurrentKey || key == null) {
      throw const GroupKeyUnavailable('La clé de chiffrement du groupe n\'est pas encore arrivée sur cet appareil.');
    }
    final out = Map<String, dynamic>.from(doc);
    var sealedAny = false;

    Future<void> seal(String field, String plain, {String? as}) async {
      out[as ?? field] = await encryptField(key, plain, groupId: groupId, epoch: st.epoch, msgId: msgId, field: as ?? field);
      sealedAny = true;
    }

    final type = '${doc['message_type'] ?? 'text'}';
    if (type == 'text' && doc[fMessage] is String && (doc[fMessage] as String).isNotEmpty) await seal(fMessage, doc[fMessage] as String);
    if (doc[fCaption] is String && (doc[fCaption] as String).isNotEmpty) await seal(fCaption, doc[fCaption] as String);
    if (doc[fReply] is String && (doc[fReply] as String).isNotEmpty) await seal(fReply, doc[fReply] as String);
    if (doc['link_preview'] is Map) {
      await seal('link_preview', jsonEncode(doc['link_preview']), as: fLinkPreview);
      out.remove('link_preview');
    }
    if (sealedAny) {
      out['is_encrypted'] = true;
      out['key_epoch'] = st.epoch;
    }
    return out;
  }

  /// Déchiffre un document de message pour l'affichage. Ne lève jamais d'exception :
  /// - message sans chiffrement (anciens messages) : rendu tel quel ;
  /// - clé indisponible ou message altéré : champs remplacés par [lockedText] (pour le texte) et `_locked: true`.
  Future<Map<String, dynamic>> openMessage(String groupId, String me, Map<String, dynamic> msg) async {
    if (!isEncryptedMessage(msg)) return msg;
    final epoch = _asInt(msg['key_epoch']);
    final msgId = '${msg['id'] ?? ''}';
    var key = _keys[_ck(me, groupId)]?[epoch] ?? await _keyFromStore(me, groupId, epoch);
    if (key == null && _states[_ck(me, groupId)] == null) {
      // premier message lu avant le chargement des clés : on les charge (échec réseau = message verrouillé, jamais d'exception)
      try {
        await ensureLoaded(groupId, me);
      } catch (_) {}
      key = _keys[_ck(me, groupId)]?[epoch];
    }
    final out = Map<String, dynamic>.from(msg);
    var locked = false;

    Future<String?> open(String field) async {
      final raw = msg[field];
      if (raw is! String || !raw.startsWith(fieldPrefix)) return null;
      if (key == null) {
        locked = true;
        return null;
      }
      try {
        return await decryptField(key, raw, groupId: groupId, epoch: epoch, msgId: msgId, field: field);
      } catch (_) {
        locked = true;
        return null;
      }
    }

    for (final f in [fMessage, fCaption, fReply]) {
      if (msg[f] is String && (msg[f] as String).startsWith(fieldPrefix)) {
        final clear = await open(f);
        out[f] = clear ?? (f == fMessage ? lockedText : '');
      }
    }
    if (msg[fLinkPreview] is String) {
      final clear = await open(fLinkPreview);
      out.remove(fLinkPreview);
      if (clear != null) {
        try {
          out['link_preview'] = jsonDecode(clear);
        } catch (_) {}
      }
    }
    if (locked) out['_locked'] = true;
    return out;
  }

  Future<List<Map<String, dynamic>>> openMessages(String groupId, String me, List<Map<String, dynamic>> msgs) async {
    final out = <Map<String, dynamic>>[];
    for (final m in msgs) {
      out.add(await openMessage(groupId, me, m));
    }
    return out;
  }

  /// Texte d'aperçu (liste de conversations) : déchiffré si la clé est déjà sur l'appareil, sinon « Message chiffré ».
  Future<String> previewText(String groupId, String me, Map<String, dynamic> msg) async {
    final opened = await openMessage(groupId, me, msg);
    if (opened['_locked'] == true) return 'Message chiffré';
    return '${opened['message'] ?? ''}';
  }

  /// Vrai si [msg] porte des champs chiffrés (et seulement dans ce cas : un texte quelconque commençant par le préfixe n'est pas pris pour un chiffré).
  static bool isEncryptedMessage(Map<String, dynamic> msg) =>
      msg['is_encrypted'] == true && msg['is_deleted'] != true && msg['key_epoch'] is num && (msg['key_epoch'] as num) > 0;

  Future<SecretKey?> _keyFromStore(String me, String groupId, int epoch) async {
    try {
      final saved = await store.load(me, groupId);
      final b = saved[epoch];
      if (b == null) return null;
      final key = SecretKey(b);
      _keys.putIfAbsent(_ck(me, groupId), () => {})[epoch] = key;
      return key;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────────────────────
  // Primitives (publiques pour les tests)
  // ─────────────────────────────────────────────────────────────────────────────────────────────

  static List<int> _aad(String groupId, int epoch, String msgId, String field) => utf8.encode('afrolook_gmsg_v1|$groupId|$epoch|$msgId|$field');

  static Future<String> encryptField(SecretKey key, String plain, {required String groupId, required int epoch, required String msgId, required String field}) async {
    final box = await _aes.encrypt(utf8.encode(plain), secretKey: key, aad: _aad(groupId, epoch, msgId, field));
    return '$fieldPrefix${base64Encode(box.concatenation())}';
  }

  static Future<String> decryptField(SecretKey key, String sealed, {required String groupId, required int epoch, required String msgId, required String field}) async {
    final raw = base64Decode(sealed.substring(fieldPrefix.length));
    final box = SecretBox.fromConcatenation(raw, nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength);
    return utf8.decode(await _aes.decrypt(box, secretKey: key, aad: _aad(groupId, epoch, msgId, field)));
  }

  static String _envCtx(String groupId, int epoch, String wrapperId, String recipientId) => 'afrolook_group_envelope_v1|$groupId|$epoch|$wrapperId|$recipientId';

  static Future<SecretKey> _envKey(SimpleKeyPair myPair, List<int> theirPublic, String ctx) async {
    final shared = await _x25519.sharedSecretKey(keyPair: myPair, remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519));
    return _hkdf.deriveKey(secretKey: shared, nonce: utf8.encode('afrolook_group_envelope_salt_v1'), info: utf8.encode(ctx));
  }

  /// Enveloppe : la clé de groupe [groupKey] chiffrée pour [recipientId], posée par [wrapperId].
  static Future<String> wrapKey(List<int> groupKey, {required SimpleKeyPair myPair, required List<int> theirPublic, required String groupId, required int epoch, required String wrapperId, required String recipientId}) async {
    final ctx = _envCtx(groupId, epoch, wrapperId, recipientId);
    final box = await _aes.encrypt(groupKey, secretKey: await _envKey(myPair, theirPublic, ctx), aad: utf8.encode(ctx));
    return '$envelopePrefix${base64Encode(box.concatenation())}';
  }

  static Future<List<int>> openEnvelope(String envelope, {required SimpleKeyPair myPair, required List<int> theirPublic, required String groupId, required int epoch, required String wrapperId, required String recipientId}) async {
    if (!envelope.startsWith(envelopePrefix)) throw const FormatException('enveloppe inconnue');
    final ctx = _envCtx(groupId, epoch, wrapperId, recipientId);
    final box = SecretBox.fromConcatenation(base64Decode(envelope.substring(envelopePrefix.length)), nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength);
    final clear = await _aes.decrypt(box, secretKey: await _envKey(myPair, theirPublic, ctx), aad: utf8.encode(ctx));
    if (clear.length != 32) throw const FormatException('clé de groupe de taille inattendue');
    return clear;
  }

  // ─────────────────────────────────────────────────────────────────────────────────────────────
  // Ma clé publique, annuaire
  // ─────────────────────────────────────────────────────────────────────────────────────────────

  /// S'assure que MA clé publique est dans l'annuaire de l'API et retourne sa version.
  /// Si l'annuaire contient une AUTRE clé que celle de cet appareil (autre appareil), on ne l'écrase pas : [GroupKeyIdentityMismatch].
  Future<int> _ensureMyKeyPublished(String me) async {
    final cached = _myKeyVersion[me];
    if (cached != null) return cached;
    final pair = await identity.keyPair(me);
    final pubB64 = base64Encode((await pair.extractPublicKey()).bytes);
    final dir = (await backend.publicKeys([me]))[me];
    int version;
    if (dir == null) {
      version = _asInt((await backend.publishMyKey(pubB64))['version']);
    } else if ('${dir['public_key']}' == pubB64) {
      version = _asInt(dir['version']);
    } else {
      throw GroupKeyIdentityMismatch();
    }
    _publishedFor.add(me);
    return _myKeyVersion[me] = version;
  }

  Future<Map<String, Map<String, dynamic>>> _safePublicKeys(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    return backend.publicKeys(list);
  }

  /// Oublie tout ce qui est en mémoire (déconnexion). Les clés conservées dans le stockage sécurisé restent.
  void clearMemory() {
    _keys.clear();
    _states.clear();
    _inFlight.clear();
    _publishedFor.clear();
    _myKeyVersion.clear();
  }

  static int _asInt(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
  static List<int> _sorted(Iterable<int> it) => (it.toList()..sort());
}

/// État du chiffrement d'un groupe pour la personne connectée.
class GroupKeyState {
  const GroupKeyState({
    required this.encrypted,
    required this.epoch,
    required this.rotationRequired,
    required this.openedEpochs,
    required this.unreadableEpochs,
    required this.pendingMembers,
    required this.changedKeyUsers,
    required this.hasCurrentKey,
    required this.identityMismatch,
    required this.isMember,
  });

  /// Le groupe est chiffré (époque courante > 0).
  final bool encrypted;

  /// Époque courante (0 = non chiffré).
  final int epoch;

  /// Un départ ou une exclusion exige une nouvelle clé (un administrateur doit la distribuer).
  final bool rotationRequired;

  /// Époques dont la clé est disponible sur cet appareil.
  final List<int> openedEpochs;

  /// Époques dont l'enveloppe existe mais n'a pas pu être ouverte (clé de cet appareil différente de celle de l'annuaire, enveloppe altérée…).
  final List<int> unreadableEpochs;

  /// Administrateurs seulement : membres qui attendent encore la clé de l'époque courante.
  final List<String> pendingMembers;

  /// Contacts dont la clé publique a changé (avertissement non acquitté), parmi ceux rencontrés lors de ce chargement.
  final List<String> changedKeyUsers;

  /// La clé de l'époque courante est disponible : on peut envoyer et lire les nouveaux messages.
  final bool hasCurrentKey;

  /// L'annuaire contient une autre clé que celle de cet appareil (compte utilisé sur un autre appareil).
  final bool identityMismatch;

  /// Faux quand l'API ne reconnaît pas la personne comme membre du groupe (seules les clés déjà gardées servent).
  final bool isMember;

  /// En attente de la clé de l'époque courante.
  bool get waitingForKey => encrypted && !hasCurrentKey;
}

/// Compte rendu d'une synchronisation faite par un administrateur.
class GroupSyncReport {
  const GroupSyncReport(this.state, {this.enabled = false, this.rotated = false, this.distributed = 0, this.missingKeys = const [], this.changedKeyUsers = const []});

  final GroupKeyState state;

  /// Le chiffrement vient d'être activé (époque 1).
  final bool enabled;

  /// Une nouvelle époque vient d'être créée.
  final bool rotated;

  /// Nombre d'enveloppes envoyées.
  final int distributed;

  /// Membres sans clé publique dans l'annuaire : ils attendent (rien ne peut leur être envoyé).
  final List<String> missingKeys;

  /// Destinataires dont la clé publique a changé depuis la dernière fois.
  final List<String> changedKeyUsers;
}

/// Le message ne peut pas être chiffré : l'envoi doit être refusé.
class GroupKeyUnavailable implements Exception {
  const GroupKeyUnavailable(this.message);
  final String message;
  @override
  String toString() => 'GroupKeyUnavailable: $message';
}

/// L'annuaire contient une autre clé que celle de cet appareil.
class GroupKeyIdentityMismatch implements Exception {
  @override
  String toString() => 'GroupKeyIdentityMismatch';
}

/// Erreur de l'API des clés de groupe (code stable de l'API : invalid_epoch, invalid_recipients, invalid_wrapper_key, not_found…).
class GroupKeyApiError implements Exception {
  const GroupKeyApiError(this.status, this.code, [this.message = '']);
  final int status;
  final String code;
  final String message;
  @override
  String toString() => 'GroupKeyApiError($status, $code): $message';
}

/// Accès à l'API : enveloppes, annuaire des clés publiques, membres. Voir `GroupKeysApi`.
abstract class GroupKeyBackend {
  /// `GET /v1/groups/{id}/keys`.
  Future<Map<String, dynamic>> fetchKeys(String groupId);

  /// `POST /v1/groups/{id}/keys`.
  Future<Map<String, dynamic>> postEnvelopes(String groupId, int epoch, List<Map<String, dynamic>> envelopes);

  /// Clés publiques ACTUELLES de plusieurs personnes : `userId -> {public_key, version}` (les absents n'ont pas de clé).
  Future<Map<String, Map<String, dynamic>>> publicKeys(List<String> userIds);

  /// Identifiants de tous les membres du groupe.
  Future<List<String>> memberIds(String groupId);

  /// `PUT /v1/me/keys`.
  Future<Map<String, dynamic>> publishMyKey(String publicKeyB64);
}

/// Paire de clés X25519 de cet appareil pour [userId] (la même que celle des chats 1 à 1).
abstract class GroupKeyIdentity {
  Future<SimpleKeyPair> keyPair(String userId);
}

/// Conservation des clés de groupe déjà ouvertes (stockage sécurisé du téléphone) : lecture hors ligne, et après un départ du groupe.
abstract class GroupKeyStore {
  Future<Map<int, List<int>>> load(String userId, String groupId);
  Future<void> save(String userId, String groupId, int epoch, List<int> key);
}

/// Stockage en mémoire (tests).
class MemoryGroupKeyStore implements GroupKeyStore {
  final Map<String, Map<int, List<int>>> data = {};

  @override
  Future<Map<int, List<int>>> load(String userId, String groupId) async => Map<int, List<int>>.from(data['$userId|$groupId'] ?? const {});

  @override
  Future<void> save(String userId, String groupId, int epoch, List<int> key) async => (data['$userId|$groupId'] ??= {})[epoch] = key;
}
