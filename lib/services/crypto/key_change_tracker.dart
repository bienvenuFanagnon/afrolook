import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Résultat de l'observation de la clé publique d'un contact.
enum KeyCheck {
  /// Première fois qu'on voit la clé de cette personne : elle est retenue (confiance à la première utilisation).
  firstSeen,

  /// Même clé que la dernière fois, aucun avertissement en attente.
  unchanged,

  /// La clé a changé (nouvel appareil, réinstallation… ou tentative d'usurpation) et l'avertissement n'a pas encore été acquitté.
  changed,
}

/// Stockage clé/valeur minimal (remplaçable dans les tests).
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Stockage sécurisé du téléphone.
class SecureKeyValueStore implements KeyValueStore {
  const SecureKeyValueStore();
  static const _s = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
}

/// Stockage en mémoire (tests).
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

/// Avertit quand la clé publique d'un contact change (fiche 34, §3.7).
///
/// Principe « confiance à la première utilisation » : la première clé vue pour une personne est retenue sur l'appareil. Si l'annuaire de l'API
/// renvoie ensuite une autre clé, l'avertissement reste actif tant que l'utilisateur ne l'a pas acquitté ([acknowledge]). Aucun texte de message
/// n'est concerné : seules des clés PUBLIQUES sont mémorisées.
/// Utilisé par les groupes ([GroupCryptoService]) et par les conversations 1 à 1 ([EncryptionService.getChatKey]).
class KeyChangeTracker {
  KeyChangeTracker(this._store);

  final KeyValueStore _store;

  /// Instance de l'application (stockage sécurisé).
  static final KeyChangeTracker shared = KeyChangeTracker(const SecureKeyValueStore());

  static String _k(String me, String contact) => 'key_trust_${me}_$contact';

  /// Observe la clé actuelle (base64) et sa version dans l'annuaire pour [contactId], vue par [myUserId].
  Future<KeyCheck> observe(String myUserId, String contactId, String publicKeyB64, int version) async {
    if (myUserId.isEmpty || contactId.isEmpty || contactId == myUserId || publicKeyB64.isEmpty) return KeyCheck.unchanged;
    try {
      final raw = await _store.read(_k(myUserId, contactId));
      if (raw == null) {
        await _store.write(_k(myUserId, contactId), jsonEncode({'pub': publicKeyB64, 'ver': version, 'warn': false}));
        return KeyCheck.firstSeen;
      }
      final cur = jsonDecode(raw) as Map<String, dynamic>;
      if (cur['pub'] == publicKeyB64) {
        return cur['warn'] == true ? KeyCheck.changed : KeyCheck.unchanged;
      }
      await _store.write(
        _k(myUserId, contactId),
        jsonEncode({'pub': publicKeyB64, 'ver': version, 'warn': true, 'prev': cur['pub'], 'prev_ver': cur['ver']}),
      );
      return KeyCheck.changed;
    } catch (_) {
      return KeyCheck.unchanged; // un stockage illisible ne doit jamais bloquer la messagerie
    }
  }

  /// Vrai si un avertissement de changement de clé est en attente pour [contactId].
  Future<bool> hasWarning(String myUserId, String contactId) async {
    try {
      final raw = await _store.read(_k(myUserId, contactId));
      if (raw == null) return false;
      return (jsonDecode(raw) as Map<String, dynamic>)['warn'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Parmi [contactIds], ceux dont la clé a changé et dont l'avertissement n'a pas été acquitté.
  Future<List<String>> warningsAmong(String myUserId, Iterable<String> contactIds) async {
    final out = <String>[];
    for (final id in contactIds) {
      if (await hasWarning(myUserId, id)) out.add(id);
    }
    return out;
  }

  /// L'utilisateur a pris connaissance du changement : la nouvelle clé devient la référence.
  Future<void> acknowledge(String myUserId, String contactId) async {
    try {
      final raw = await _store.read(_k(myUserId, contactId));
      if (raw == null) return;
      final cur = Map<String, dynamic>.from(jsonDecode(raw) as Map)
        ..['warn'] = false
        ..remove('prev')
        ..remove('prev_ver');
      await _store.write(_k(myUserId, contactId), jsonEncode(cur));
    } catch (_) {}
  }
}
