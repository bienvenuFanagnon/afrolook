import 'dart:convert';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/crypto/group_crypto_service.dart';
import 'package:afrotok/services/crypto/key_change_tracker.dart';
import 'package:afrotok/services/encryption_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Liaison de [GroupCryptoService] avec l'API Laravel (`GroupKeyController`, `KeyController`, membres du groupe).
/// L'API ne voit que des enveloppes opaques et des clés PUBLIQUES.
class GroupKeysApi implements GroupKeyBackend {
  const GroupKeysApi();

  static const int _dirChunk = 50; // `POST /v1/users/keys` : 50 identifiants au plus

  Never _translate(ApiException e) => throw GroupKeyApiError(e.status, e.code, e.message);

  @override
  Future<Map<String, dynamic>> fetchKeys(String groupId) async {
    try {
      return await ChatApi.groupKeys(groupId);
    } on ApiException catch (e) {
      _translate(e);
    }
  }

  @override
  Future<Map<String, dynamic>> postEnvelopes(String groupId, int epoch, List<Map<String, dynamic>> envelopes) async {
    try {
      return await ChatApi.postGroupKeys(groupId, epoch, envelopes);
    } on ApiException catch (e) {
      _translate(e);
    }
  }

  @override
  Future<Map<String, Map<String, dynamic>>> publicKeys(List<String> userIds) async {
    final out = <String, Map<String, dynamic>>{};
    for (var i = 0; i < userIds.length; i += _dirChunk) {
      final chunk = userIds.sublist(i, (i + _dirChunk).clamp(0, userIds.length));
      for (final k in await UsersApi.userKeys(chunk)) {
        final id = '${k['user_id']}';
        if (id.isNotEmpty) out[id] = k;
      }
    }
    return out;
  }

  @override
  Future<List<String>> memberIds(String groupId) async {
    final ids = <String>[];
    String? cursor;
    for (var page = 0; page < 40; page++) {
      final r = await ChatApi.members(groupId, cursor: cursor, limit: 100);
      for (final m in r.items) {
        final id = '${m['user_id'] ?? ''}';
        if (id.isNotEmpty) ids.add(id);
      }
      cursor = r.next;
      if (cursor == null) break;
    }
    return ids;
  }

  @override
  Future<Map<String, dynamic>> publishMyKey(String publicKeyB64) => UsersApi.publishKey(publicKeyB64);
}

/// Paire de clés de cet appareil : la même que celle des chats 1 à 1 ([EncryptionService]), pour ne pas dupliquer le stockage de la clé privée.
class EncryptionServiceIdentity implements GroupKeyIdentity {
  const EncryptionServiceIdentity();

  @override
  Future<SimpleKeyPair> keyPair(String userId) => EncryptionService.myKeyPair(userId);
}

/// Clés de groupe déjà ouvertes, gardées dans le stockage sécurisé du téléphone (une entrée par personne et par groupe).
class SecureGroupKeyStore implements GroupKeyStore {
  const SecureGroupKeyStore();
  static const _s = FlutterSecureStorage();

  static String _k(String userId, String groupId) => 'group_keys_${userId}_$groupId';

  @override
  Future<Map<int, List<int>>> load(String userId, String groupId) async {
    final raw = await _s.read(key: _k(userId, groupId));
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((e, v) => MapEntry(int.parse(e), base64Decode('$v')));
  }

  @override
  Future<void> save(String userId, String groupId, int epoch, List<int> key) async {
    final cur = await load(userId, groupId);
    cur[epoch] = key;
    await _s.write(key: _k(userId, groupId), value: jsonEncode(cur.map((e, v) => MapEntry('$e', base64Encode(v)))));
  }
}

GroupCryptoService? _shared;

/// Service de chiffrement des groupes de l'application (API + clé de l'appareil + stockage sécurisé + avertissement de changement de clé).
GroupCryptoService get groupCrypto => _shared ??= GroupCryptoService(
      backend: const GroupKeysApi(),
      identity: const EncryptionServiceIdentity(),
      store: const SecureGroupKeyStore(),
      tracker: KeyChangeTracker.shared,
    );
